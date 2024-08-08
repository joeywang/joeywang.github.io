---
layout: post
title:  "Fail VS. Raise - more about exception in Ruby"
date:   2024-08-02 14:41:26 +0100
categories: Rails
---
# Fail VS. Raise - more about exception in Ruby

When I read some code I can see somewhere we are using fail and somewhere else raise instead. 
It got me thinking about the difference. 

It turns out that fail is just an alias of raise

```ruby
r = method(:raise)
f = method(:fail)

f == r # => true
f.owner == r.owner # => Kernel
```

And you can see this in C as well

```c
//Actually they are same in eval.c  
rb_define_global_function("raise", f_raise, -1);
rb_define_global_function("fail", f_raise, -1);
```

And you can also confirm this with lldb

```bash
(lldb) b rb_f_raise
Process 30661 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x0000000100aed8b8 libruby.3.3.dylib`rb_f_raise [inlined] extract_raise_opts(argc=1, argv=<unavailable>, opts=0x000000016fdfe460) at eval.c:716:9
   713 	extract_raise_opts(int argc, VALUE *argv, VALUE *opts)
   714 	{
   715 	    int i;
-> 716 	    if (argc > 0) {
   717 	        VALUE opt;
   718 	        argc = rb_scan_args(argc, argv, "*:", NULL, &opt);
   719 	        if (!NIL_P(opt)) {
Target 0: (ruby) stopped.
(lldb) bt
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
  * frame #0: 0x0000000100aed8b8 libruby.3.3.dylib`rb_f_raise [inlined] extract_raise_opts(argc=1, argv=<unavailable>, opts=0x000000016fdfe460) at eval.c:716:9
    frame #1: 0x0000000100aed8b8 libruby.3.3.dylib`rb_f_raise(argc=1, argv=0x0000000158028068) at eval.c:741:12
    frame #2: 0x0000000100aeeca4 libruby.3.3.dylib`f_raise(c=<unavailable>, v=<unavailable>, _=<unavailable>) at eval.c:789:12
    frame #3: 0x0000000100c93194 libruby.3.3.dylib`vm_call_cfunc_with_frame_(ec=0x0000000155804a80, reg_cfp=0x0000000158127f58, calling=<unavailable>, argc=1, argv=0x0000000158028068, stack_bottom=0x0000000158028060) at vm_insnhelper.c:3502:11
    frame #4: 0x0000000100c78bf4 libruby.3.3.dylib`vm_exec_core [inlined] vm_sendish(ec=0x0000000155804a80, reg_cfp=0x0000000158127f58, cd=0x0000600000412470, block_handler=0, method_explorer=mexp_search_method) at vm_insnhelper.c:5593:15
    frame #5: 0x0000000100c78af0 libruby.3.3.dylib`vm_exec_core(ec=<unavailable>) at insns.def:834:11
    frame #6: 0x0000000100c75c18 libruby.3.3.dylib`rb_vm_exec [inlined] vm_exec_loop(ec=0x0000000155804a80, state=<unavailable>, tag=0x000000016fdfe680, result=<unavailable>) at vm.c:2513:22
    frame #7: 0x0000000100c75b60 libruby.3.3.dylib`rb_vm_exec(ec=0x0000000155804a80) at vm.c:2492:18
    frame #8: 0x0000000100aed380 libruby.3.3.dylib`rb_ec_exec_node(ec=0x0000000155804a80, n=0x000000010027dc78) at eval.c:287:9
    frame #9: 0x0000000100aed278 libruby.3.3.dylib`ruby_run_node(n=0x000000010027dc78) at eval.c:328:30
    frame #10: 0x0000000100003f24 ruby`main [inlined] rb_main(argc=2, argv=0x000000016fdfeb90) at main.c:39:12
    frame #11: 0x0000000100003f08 ruby`main(argc=2, argv=0x000000016fdfeb90) at main.c:58:12
    frame #12: 0x000000019226a0e0 dyld`start + 2360
```
