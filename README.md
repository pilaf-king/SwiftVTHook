# SwiftVTHook（beta）

## 介绍
SwiftVTHook 是一种基于Swift的虚函数表的函数hook 方案，目前已经形成demo。不包括Swift msg_send以及静态地址直接调用的方式进行函数调用。

## 进展
目前SwiftVTHook处于理论实验阶段，编译器对Swift的优化影响、泛型、Type结构等还需要进一步完善。

## demo
demo 只支持真机arm64架构。建议release模式下进行编译运行。由于相对对OC比较熟悉，因此核心代码采用OC编写。

## 风险
在修改编译选项时，代码可能存在优化，跳表方式的函数调用转为静态地址调用，因此可能失效。
另外，
demo中可能存在的问题通过 #warning 的方式做了介绍
