---
layout: post
title: "AI Application Architecture: LLM + Memory + Tools"
description: "The five components a production AI application actually needs beyond the model itself: memory, tools, retrieved knowledge, and structured context."
date: "2026-02-25"
categories: [AI]
start_here: true
series: "Software Engineering in the LLM Era"
tags: [llm, ai, agents]
---
<audio controls preload="metadata" src="/assets/audio/ai-application-architecture-llm-memory-tools-summary.ogg">
  Your browser does not support the audio element.
</audio>

*Part of the [AI & Agents reading path](/ai-agents/).*

You build a chatbot. It works fine for simple questions. Then real users show up.

They ask about product details the model does not really know. They want it to check an order, update a setting, or remember what happened yesterday. That is where the cracks show.

You've hit the wall that every AI developer encounters: an LLM alone is not an application. It's a component. This is where a lot of AI projects go sideways: teams treat the LLM as the solution, not as one piece of a larger system. They build prompts when they really need architecture.

An LLM is the reasoning engine, but a reasoning engine without senses, memory, and hands can't accomplish much on its own. A complete AI application has five core components:

```
┌─────────────────────────────────────────────────────────┐
│                   AI Application                        │
│                                                         │
│   LLM        ← the reasoning engine                     │
│   Memory     ← conversation history, user state         │
│   Tools      ← APIs, databases, external services       │
│   Knowledge  ← RAG, documents, domain data               │
│   Context    ← instructions, constraints, format         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Component 1: The LLM (Reasoning Engine)

The LLM interprets input, decides what actions to take, generates responses, and orchestrates the other components. What it does not do: store information between calls, access real-time data, execute actions, or guarantee accuracy.

```python
class LLMComponent:
    def __init__(self, model_name, temperature=0.7):
        self.model_name = model_name
        self.temperature = temperature

    def generate(self, messages, tools=None):
        return call_llm_api(
            model=self.model_name,
            messages=messages,
            temperature=self.temperature,
            tools=tools,
        )
```

Key considerations: balance model choice against cost and capability, use a lower temperature for deterministic tasks and higher for creative ones, design prompts with the context window in mind, and track tokens per request so cost doesn't creep up unnoticed.

## Component 2: Memory (State Management)

Memory provides continuity: conversation history, user preferences, session state, and personalization over time. It splits roughly into short-term memory (the current context window), long-term memory (persistent, database-backed), and episodic memory (a specific session's task progress).

```python
class MemoryManager:
    def __init__(self, user_id, db_connection):
        self.user_id = user_id
        self.db = db_connection
        self.context_window = []

    def add_message(self, role, content):
        self.context_window.append({"role": role, "content": content})
        self.db.save_message(self.user_id, role, content)

    def get_context(self, max_tokens=4000):
        """Return recent messages that fit within the token budget."""
        messages, tokens = [], 0
        for msg in reversed(self.context_window):
            msg_tokens = count_tokens(msg["content"])
            if tokens + msg_tokens > max_tokens:
                break
            messages.insert(0, msg)
            tokens += msg_tokens
        return messages
```

As a conversation grows past the token budget, a sliding window (keep only the last N messages) is the simplest strategy. Summarizing older messages preserves more information per token. Retrieving only the messages relevant to the current query, by embedding similarity, scales furthest but adds a retrieval step of its own.

## Component 3: Tools (Action Execution)

Tools give the system capabilities: executing actions, accessing real-time data, running computations, and reaching external systems.

```python
class Tool:
    def __init__(self, name, description, function):
        self.name, self.description, self.function = name, description, function

    def to_llm_schema(self):
        return {"type": "function", "function": {
            "name": self.name, "description": self.description,
            "parameters": self.get_parameter_schema(),
        }}

    def execute(self, **kwargs):
        return self.function(**kwargs)


tools = [
    Tool("get_weather", "Get current weather for a location", get_weather_api),
    Tool("search_database", "Search the product database", search_products),
    Tool("create_ticket", "Create a support ticket", create_support_ticket),
]
```

The tool-calling loop: the LLM receives the user's input plus the tool definitions, decides whether to respond directly or call a tool, and if it calls one, the system executes it, returns the result to the LLM, and the LLM generates the final response from that result.

## Component 4: Knowledge (RAG)

Knowledge grounds the system in domain-specific data: accurate answers about your product or content, fewer hallucinations, and information beyond the model's training cutoff.

```python
class RAGSystem:
    def __init__(self, vector_db, embedding_model):
        self.vector_db, self.embedding_model = vector_db, embedding_model

    def index_documents(self, documents):
        for doc in documents:
            for chunk in self.chunk_document(doc):
                embedding = self.embedding_model.encode(chunk.text)
                self.vector_db.upsert(id=chunk.id, embedding=embedding,
                                       metadata={"text": chunk.text, "source": doc.source})

    def query(self, question, top_k=5):
        query_embedding = self.embedding_model.encode(question)
        results = self.vector_db.similarity_search(query_embedding, top_k=top_k)
        return "\n\n".join(r.metadata["text"] for r in results)
```

Indexing chunks and embeds documents into a vector database ahead of time. At query time, the question gets embedded, the closest chunks get retrieved, and both the retrieved context and the question go to the LLM together, with an instruction to say so if the answer isn't in the context rather than guessing.

## Component 5: Context (Instructions and Constraints)

Context sets behavior and tone, defines constraints, specifies output format, and supplies few-shot examples. It layers naturally: system instructions that are always active, task instructions specific to the current request, conversation context from the session, and retrieved context from RAG.

```python
class ContextBuilder:
    def __init__(self):
        self.system_instructions, self.task_instructions, self.examples = [], [], []

    def add_system_instruction(self, instruction):
        self.system_instructions.append(instruction)
        return self

    def add_example(self, input_text, output_text):
        self.examples.append({"input": input_text, "output": output_text})
        return self

    def build(self, user_input):
        messages = [{"role": "system", "content": "\n".join(self.system_instructions)}]
        for ex in self.examples:
            messages.append({"role": "user", "content": ex["input"]})
            messages.append({"role": "assistant", "content": ex["output"]})
        messages.append({"role": "user", "content": user_input})
        return messages
```

## Putting It All Together

```python
class AIApplication:
    def __init__(self, user_id, config):
        self.llm = LLMComponent(config["model"])
        self.memory = MemoryManager(user_id, config["database"])
        self.tools = ToolExecutor(config["tools"])
        self.rag = RAGSystem(config["vector_db"], config["embedding_model"])
        self.context_builder = self._build_default_context()

    def process(self, user_input):
        self.memory.add_message("user", user_input)

        if self._needs_knowledge_retrieval(user_input):
            context = self.rag.query(user_input)
            self.context_builder.add_task_instruction(f"Use this context when relevant: {context}")

        messages = self.context_builder.build(user_input)

        if self._needs_tool_execution(user_input):
            response = self.tools.process_with_tools(user_input, self.memory)
        else:
            response = self.llm.generate(messages)

        self.memory.add_message("assistant", response)
        return response
```

Not every application needs all five components wired together. A simple chatbot is just context feeding the LLM. A RAG chatbot adds retrieval before the LLM call. An agent with tools adds a tool-decision step after the LLM responds. A full production system, the kind that needs all five, is the one worth architecting deliberately rather than growing by accretion, because that's exactly the path that leads back to the chatbot that worked fine until real users showed up.

*This is the fourth article in the **"Software Engineering in the LLM Era"** series. [Read Article 1](/posts/what-is-llm-nature-of-language-models/) | [Read Article 2](/posts/generalization-why-ai-looks-smart/) | [Read Article 3](/posts/llm-strengths-and-limitations-framework/).*
