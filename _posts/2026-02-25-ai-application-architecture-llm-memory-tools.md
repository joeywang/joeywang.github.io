---
layout: post
title: "AI Application Architecture: LLM + Memory + Tools"
date: "2026-02-25"
categories: LLM AI software-engineering series
series: "Software Engineering in the LLM Era"
---

## The Problem

You build a chatbot. It works fine for simple questions. Then real users show up.

They ask about product details the model does not really know. They want it to check an order, update a setting, or remember what happened yesterday. That is where the cracks show.

You've hit the wall that every AI developer encounters:

> **An LLM alone is not an application. It's a component.**

This is where a lot of AI projects go sideways. Teams treat the LLM as the solution, not as one piece of a larger system. They build prompts when they really need architecture.

This article is about that larger system.

If you want an AI application that survives contact with actual users, the model is only the start.

---

## The Core Architecture: Beyond the LLM

The underlying idea is simple:

> **LLM is the brain. But a brain without senses, memory, and hands can't accomplish much.**

A complete AI application has five core components:

```
┌─────────────────────────────────────────────────────────┐
│                   AI Application                        │
│                                                         │
│  ┌─────────────┐                                       │
│  │     LLM     │ ← The reasoning engine                │
│  └──────┬──────┘                                       │
│         │                                               │
│  ┌──────┴──────┐                                       │
│  │   Memory    │ ← Conversation history, user state    │
│  └──────┬──────┘                                       │
│         │                                               │
│  ┌──────┴──────┐                                       │
│  │    Tools    │ ← APIs, databases, external services  │
│  └──────┬──────┘                                       │
│         │                                               │
│  ┌──────┴──────┐                                       │
│  │  Knowledge  │ ← RAG, documents, domain data         │
│  └──────┬──────┘                                       │
│         │                                               │
│  ┌──────┴──────┐                                       │
│  │   Context   │ ← Instructions, constraints, format   │
│  └─────────────┘                                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

That is the stack I want to walk through.

---

## Component 1: The LLM (Reasoning Engine)

### What It Does

The LLM is the **reasoning core**. It:
- Interprets user input
- Decides what actions to take
- Generates responses
- Orchestrates other components

### What It Doesn't Do

The LLM does NOT:
- Store information between calls
- Access real-time data
- Execute actions
- Guarantee accuracy

### Implementation Pattern

```python
class LLMComponent:
    def __init__(self, model_name, temperature=0.7):
        self.model_name = model_name
        self.temperature = temperature
    
    def generate(self, messages, tools=None):
        """
        Generate a response, optionally with tool calling.
        """
        response = call_llm_api(
            model=self.model_name,
            messages=messages,
            temperature=self.temperature,
            tools=tools  # Optional: available tools
        )
        return response
    
    def generate_with_retry(self, messages, max_retries=3):
        """
        Generate with retry logic for reliability.
        """
        for attempt in range(max_retries):
            try:
                return self.generate(messages)
            except RateLimitError:
                wait_exponential(attempt)
        raise MaxRetriesExceeded()
```

### Key Considerations

| Consideration | Guidance |
|--------------|----------|
| Model selection | Balance cost vs. capability |
| Temperature | Lower for deterministic tasks, higher for creative |
| Token limits | Design prompts with context window in mind |
| Cost monitoring | Track tokens per request, implement budgets |

---

## Component 2: Memory (State Management)

### What It Does

Memory provides **continuity**. It:
- Stores conversation history
- Maintains user preferences
- Tracks session state
- Enables personalization over time

### Types of Memory

```
┌─────────────────────────────────────────┐
│            Memory Hierarchy             │
├─────────────────────────────────────────┤
│  Short-term (Context Window)            │
│  - Current conversation                 │
│  - Immediate context                    │
│  - Limited by token window              │
├─────────────────────────────────────────┤
│  Long-term (Persistent Storage)         │
│  - User preferences                     │
│  - Historical interactions              │
│  - Learned information                  │
│  - Unlimited (database-backed)          │
├─────────────────────────────────────────┤
│  Episodic (Session-based)               │
│  - Specific conversations               │
│  - Task progress                        │
│  - Temporary state                      │
└─────────────────────────────────────────┘
```

### Implementation Pattern

```python
class MemoryManager:
    def __init__(self, user_id, db_connection):
        self.user_id = user_id
        self.db = db_connection
        self.context_window = []
    
    def add_message(self, role, content):
        """Add a message to short-term memory."""
        self.context_window.append({
            "role": role,
            "content": content,
            "timestamp": datetime.now()
        })
        
        # Persist to long-term storage
        self.db.save_message(self.user_id, role, content)
    
    def get_context(self, max_tokens=4000):
        """
        Get conversation context, respecting token
        """
        # Simple approach: take last N messages
        # Advanced: summarize older messages
        
        messages = []
        tokens = 0
        
        for msg in reversed(self.context_window):
            msg_tokens = count_tokens(msg["content"])
            if tokens + msg_tokens > max_tokens:
                break
            messages.insert(0, msg)
            tokens += msg_tokens
        
        return messages
    
    def get_user_preferences(self):
        """Retrieve long-term user preferences."""
        return self.db.get_preferences(self.user_id)
    
    def summarize_session(self):
        """Create a summary of the current session."""
        # Use LLM to summarize, store for future context
        summary = llm.generate(f"""
        Summarize this conversation:
        {self.context_window}
        
        Key points, decisions, and action items.
        """)
        self.db.save_session_summary(self.user_id, summary)
        return summary
```

### Memory Management Strategies

**Strategy 1: Sliding Window**
```python
def get_sliding_window(messages, window_size=10):
    """Keep only the last N messages."""
    return messages[-window_size:]
```

**Strategy 2: Summarization**
```python
def get_summarized_context(messages, max_tokens=4000):
    """Summarize older messages to save tokens."""
    if count_tokens(messages) <= max_tokens:
        return messages
    
    # Keep recent messages, summarize older ones
    recent = messages[-5:]
    older = messages[:-5]
    
    summary = llm.generate(f"Summarize: {older}")
    
    return [{"role": "system", "content": f"Previous conversation summary: {summary}"}] + recent
```

**Strategy 3: Selective Retrieval**
```python
def get_relevant_context(messages, query, db):
    """Retrieve only relevant past messages."""
    # Embed current query
    query_embedding = embed(query)
    
    # Find similar past messages
    relevant = db.similarity_search(query_embedding, top_k=5)
    
    return relevant + messages[-3:]  # Add recent context
```

---

## Component 3: Tools (Action Execution)

### What It Does

Tools provide **capabilities**. They:
- Execute actions (API calls, database operations)
- Access real-time data
- Perform computations
- Interact with external systems

### The Tool Pattern

```python
class Tool:
    def __init__(self, name, description, function):
        self.name = name
        self.description = description
        self.function = function
    
    def to_llm_schema(self):
        """Convert to LLM's expected tool schema."""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.get_parameter_schema()
            }
        }
    
    def execute(self, **kwargs):
        """Execute the tool with given parameters."""
        return self.function(**kwargs)


# Example tools
tools = [
    Tool(
        name="get_weather",
        description="Get current weather for a location",
        function=get_weather_api,
    ),
    Tool(
        name="search_database",
        description="Search the product database",
        function=search_products,
    ),
    Tool(
        name="create_ticket",
        description="Create a support ticket",
        function=create_support_ticket,
    ),
    Tool(
        name="calculate",
        description="Perform mathematical calculations",
        function=execute_python_code,
    ),
]
```

### Tool Calling Flow

```
┌─────────────────────────────────────────────────────────┐
│                  Tool Calling Loop                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. User Input                                          │
│     ↓                                                   │
│  2. LLM receives input + tool definitions               │
│     ↓                                                   │
│  3. LLM decides: respond OR call tool                   │
│     ↓                                                   │
│  4. If tool call:                                       │
│     - LLM outputs tool name + arguments                 │
│     - System executes tool                              │
│     - Tool result returned to LLM                       │
│     - LLM generates final response                      │
│     ↓                                                   │
│  5. Return response to user                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation Pattern

```python
class ToolExecutor:
    def __init__(self, tools):
        self.tools = {tool.name: tool for tool in tools}
    
    def process_with_tools(self, user_input, memory):
        """Process input with tool calling support."""
        messages = memory.get_context()
        messages.append({"role": "user", "content": user_input})
        
        # Get LLM response with tool calling enabled
        response = llm.generate(
            messages=messages,
            tools=[t.to_llm_schema() for t in self.tools]
        )
        
        # Check if LLM wants to call a tool
        if response.tool_calls:
            tool_call = response.tool_calls[0]
            tool = self.tools[tool_call.name]
            
            # Execute the tool
            result = tool.execute(**tool_call.arguments)
            
            # Add tool result to context
            messages.append(response)
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": str(result)
            })
            
            # Get final response from LLM
            final_response = llm.generate(messages=messages)
            return final_response.content
        
        return response.content
```

---

## Component 4: Knowledge (RAG)

### What It Does

Knowledge provides **grounded information**. It:
- Supplies domain-specific data
- Enables accurate responses about your product/content
- Reduces hallucinations
- Extends beyond training cutoff

### RAG Flow

```
┌─────────────────────────────────────────────────────────┐
│              RAG (Retrieval-Augmented Generation)       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Indexing Phase:                                        │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Documents│ →  │  Chunk   │ →  │  Embed   │         │
│  │          │    │  & Clean │    │  & Store │         │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                          ↓              │
│  ┌──────────────────────────────────────────┐          │
│  │         Vector Database                  │          │
│  └──────────────────────────────────────────┘          │
│                                                         │
│  Query Phase:                                           │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │  User    │ →  │  Embed   │ →  │ Similarity│         │
│  │ Question │    │ Question │    │  Search   │         │
│  └──────────┘    └──────────┘    └────┬─────┘         │
│                                        ↓               │
│  ┌──────────────────────────────────────────┐          │
│  │  Retrieved Context + Question → LLM      │          │
│  └──────────────────────────────────────────┘          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation Pattern

```python
class RAGSystem:
    def __init__(self, vector_db, embedding_model):
        self.vector_db = vector_db
        self.embedding_model = embedding_model
    
    def index_documents(self, documents):
        """Index documents for retrieval."""
        for doc in documents:
            # Chunk the document
            chunks = self.chunk_document(doc)
            
            for chunk in chunks:
                # Create embedding
                embedding = self.embedding_model.encode(chunk.text)
                
                # Store in vector DB
                self.vector_db.upsert(
                    id=chunk.id,
                    embedding=embedding,
                    metadata={
                        "text": chunk.text,
                        "source": doc.source,
                        "page": chunk.page
                    }
                )
    
    def query(self, question, top_k=5):
        """Retrieve relevant context for a question."""
        # Embed the question
        query_embedding = self.embedding_model.encode(question)
        
        # Search for similar documents
        results = self.vector_db.similarity_search(
            query_embedding,
            top_k=top_k
        )
        
        # Format context for LLM
        context = "\n\n".join([r.metadata["text"] for r in results])
        
        return context
    
    def chunk_document(self, document, chunk_size=500, overlap=50):
        """Split document into overlapping chunks."""
        chunks = []
        start = 0
        
        while start < len(document.text):
            end = start + chunk_size
            chunk_text = document.text[start:end]
            
            chunks.append(Chunk(
                id=f"{document.id}_{start}",
                text=chunk_text,
                page=document.page
            ))
            
            start += chunk_size - overlap
        
        return chunks
```

### RAG Query Pattern

```python
def answer_with_rag(question, rag_system):
    """Answer a question using RAG."""
    # Retrieve relevant context
    context = rag_system.query(question)
    
    # Generate answer based on context
    prompt = f"""
    Based on the following context, answer the question.
    If the answer is not in the context, say "I don't have enough information."
    
    Context:
    {context}
    
    Question: {question}
    
    Answer:
    """
    
    return llm.generate(prompt)
```

---

## Component 5: Context (Instructions & Constraints)

### What It Does

Context provides **guidance**. It:
- Sets behavior and tone
- Defines constraints and rules
- Specifies output format
- Provides examples (few-shot)

### Context Layers

```
┌─────────────────────────────────────────┐
│           Context Hierarchy             │
├─────────────────────────────────────────┤
│  System Instructions (Always active)    │
│  - Role definition                      │
│  - Behavioral constraints               │
│  - Safety guidelines                    │
├─────────────────────────────────────────┤
│  Task Instructions (Per-request)        │
│  - Specific task description            │
│  - Output format requirements           │
│  - Examples (few-shot)                  │
├─────────────────────────────────────────┤
│  Conversation Context (Session)         │
│  - Previous messages                    │
│  - User preferences                     │
│  - Current task state                   │
├─────────────────────────────────────────┤
│  Retrieved Context (RAG)                │
│  - Relevant documents                   │
│  - Knowledge base entries               │
│  - External data                        │
└─────────────────────────────────────────┘
```

### Implementation Pattern

```python
class ContextBuilder:
    def __init__(self):
        self.system_instructions = []
        self.task_instructions = []
        self.examples = []
    
    def add_system_instruction(self, instruction):
        """Add a system-level instruction."""
        self.system_instructions.append(instruction)
        return self
    
    def add_task_instruction(self, instruction):
        """Add a task-specific instruction."""
        self.task_instructions.append(instruction)
        return self
    
    def add_example(self, input_text, output_text):
        """Add a few-shot example."""
        self.examples.append({
            "input": input_text,
            "output": output_text
        })
        return self
    
    def build(self, user_input):
        """Build the complete context."""
        messages = []
        
        # System instructions
        if self.system_instructions:
            system_prompt = "\n".join(self.system_instructions)
            messages.append({"role": "system", "content": system_prompt})
        
        # Task instructions
        if self.task_instructions:
            task_prompt = "\n".join(self.task_instructions)
            messages.append({"role": "system", "content": task_prompt})
        
        # Few-shot examples
        for example in self.examples:
            messages.append({"role": "user", "content": example["input"]})
            messages.append({"role": "assistant", "content": example["output"]})
        
        # User input
        messages.append({"role": "user", "content": user_input})
        
        return messages


# Usage
context = (ContextBuilder()
    .add_system_instruction("You are a helpful customer support assistant.")
    .add_system_instruction("Always be polite and professional.")
    .add_task_instruction("Respond in 2-3 sentences maximum.")
    .add_task_instruction("If you don't know, offer to connect with a human.")
    .add_example(
        "My order is late",
        "I apologize for the delay. Let me look up your order status. Could you provide your order number?"
    )
    .build("Where is my package?")
)
```

---

## Putting It All Together: Complete Architecture

### The AI Application Class

```python
class AIApplication:
    def __init__(self, user_id, config):
        self.user_id = user_id
        self.llm = LLMComponent(config["model"])
        self.memory = MemoryManager(user_id, config["database"])
        self.tools = ToolExecutor(config["tools"])
        self.rag = RAGSystem(config["vector_db"], config["embedding_model"])
        self.context_builder = self._build_default_context()
    
    def _build_default_context(self):
        """Build default context builder."""
        return (ContextBuilder()
            .add_system_instruction("You are a helpful assistant.")
            .add_system_instruction("Use tools when needed for accurate information.")
            .add_system_instruction("If unsure, acknowledge uncertainty."))
    
    def process(self, user_input):
        """Process user input through the complete system."""
        # 1. Store input in memory
        self.memory.add_message("user", user_input)
        
        # 2. Check if RAG is needed
        if self._needs_knowledge_retrieval(user_input):
            context = self.rag.query(user_input)
            self.context_builder.add_task_instruction(
                f"Use this context when relevant: {context}"
            )
        
        # 3. Build messages
        messages = self.context_builder.build(user_input)
        
        # 4. Process with tools if needed
        if self._needs_tool_execution(user_input):
            response = self.tools.process_with_tools(user_input, self.memory)
        else:
            response = self.llm.generate(messages)
        
        # 5. Store response in memory
        self.memory.add_message("assistant", response)
        
        return response
    
    def _needs_knowledge_retrieval(self, input_text):
        """Determine if RAG retrieval is needed."""
        # Simple heuristic: check for domain-specific terms
        # Advanced: use classifier or LLM to decide
        domain_keywords = ["product", "feature", "pricing", "policy"]
        return any(keyword in input_text.lower() for keyword in domain_keywords)
    
    def _needs_tool_execution(self, input_text):
        """Determine if tool execution is needed."""
        # Simple heuristic: check for action verbs
        # Advanced: use LLM to classify intent
        action_verbs = ["check", "update", "create", "delete", "search"]
        return any(input_text.lower().startswith(verb) for verb in action_verbs)
```

---

## Architectural Patterns

### Pattern 1: Simple Chatbot

```
User → LLM → Response
       ↑
    Context
```

**Use when:** General conversation, no special knowledge needed.

---

### Pattern 2: RAG Chatbot

```
User → Embed → Vector DB → Context → LLM → Response
```

**Use when:** Domain-specific Q&A, product support.

---

### Pattern 3: Agent with Tools

```
User → LLM → Tool Decision → Execute → LLM → Response
```

**Use when:** Actions needed (API calls, database operations).

---

### Pattern 4: Full System

```
                    ┌──────────┐
                    │   User   │
                    └────┬─────┘
                         ↓
                    ┌──────────┐
                    │  Memory  │ ← Conversation history
                    └────┬─────┘
                         ↓
              ┌──────────┴──────────┐
              ↓                     ↓
        ┌──────────┐          ┌──────────┐
        │   RAG    │          │  Tools   │
        │ (Knowledge)          │ (Actions)│
        └────┬─────┘          └────┬─────┘
              ↓                     ↓
                    ┌──────────┐
                    │   LLM    │
                    │(Reasoning)│
                    └────┬─────┘
                         ↓
                    ┌──────────┐
                    │ Response │
                    └──────────┘
```

**Use when:** Production applications requiring all capabilities.

---

## Key Takeaways

- **LLM is one component**, not the entire application.
- **Memory** provides continuity across conversations.
- **Tools** enable actions and real-time data access.
- **Knowledge (RAG)** grounds responses in your domain.
- **Context** guides behavior and output format.
- **Choose the pattern** that matches your use case complexity.

---

## Next Article

In **Article 5: Why AI Applications Are Ecosystems**, we'll zoom out from architecture to explore how AI systems interact with users, evolve over time, and create feedback loops. We'll examine why AI applications are more like living ecosystems than traditional software.

---

*This is the fourth article in the **"Software Engineering in the LLM Era"** series. [Read Article 1](/posts/what-is-llm-nature-of-language-models/) | [Read Article 2](/posts/generalization-why-ai-looks-smart/) | [Read Article 3](/posts/llm-strengths-and-limitations-framework/).*

---

💬 **What's your experience building AI applications? Which component has been most challenging in your projects? Share in the comments!** 🚀
