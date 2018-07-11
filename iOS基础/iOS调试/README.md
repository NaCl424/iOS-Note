#### 断点
>普通断点

>全局断点

>条件断点

条件断点中的Add Symbolic BreakPoint为某一方法加断点，可以快速定位像unrecognized selector sent to instance 0xaxxxx 这种错误
#### LLDB
>lldb命令

expression命令
```expression <cmd-options> -- <expr>```

1.在代码运行过程中，可以通过执行某个表达式来动态改变程序运行的轨迹。
如：

```
// 改变颜色
(lldb) expression -- self.view.backgroundColor = [UIColor redColor]
// 刷新界面
(lldb) expression -- (void)[CATransaction flush]
```

2.打印

```
(lldb) expression -- self.view
(UIView *) $1 = 0x00007fe322c18a10
```

>p & print & call命令

一般情况下，我们直接用expression还是用得比较少的，更多时候我们用的是p、print、call。这三个命令其实都是expression --的别名

>po命令

打印对象

>thread backtrace & bt命令

线程堆栈信息

>c & n & s & finish命令

c/ continue/ thread continue: 这三个命令表示程序继续运行
n/ next/ thread step-over: 这三个命令表示单步运行
s/ step/ thread step-in: 这三个命令表示进入某个方法
finish/ step-out: 这两个命令表示直接走完当前方法，返回到上层frame

>frame variable

打印当前所有变量

http://lldb.llvm.org/lldb-gdb.html
#### 打印日志

一般在代码中使用NSLog()方法在控制台输出信息。但是在真机上日志无法保存，所以需要将Log日志重定向输出到文件中保存。

```objc
//获取Document目录下的Log文件夹，若没有则新建
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
NSFileManager *fileManager = [NSFileManager defaultManager];

BOOL fileExists = [fileManager fileExistsAtPath:logDirectory];
if (!fileExists) {
	[fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
}

NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
[formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

//每次启动后都保存一个新的日志文件中
NSString *dateStr = [formatter stringFromDate:[NSDate date]];
NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.txt",dateStr];

// freopen 重定向输出输出流，将log输入到文件
freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
```
在APP刚启动的方法中调用以上方法，并且在应用程序的Info.plist文件中添加UIFileSharingEnabled键，并将键值设置为YES。这样就可以通过iTune查看指定应用程序的共享文件夹，将文件拷贝到电脑上查看。

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
```

#### 内存分析和Instruments
MRR模式(retain/release)
ARC模式下内存泄漏主要原因：循环引用、C语言API(如：core Foundation框架 Core Graphics框架)

>1、静态内存分析（Analyze）

不运行程序，直接对代码进行内存分析，查看代码是否有内存泄露或潜在的内存泄露
优点：分析速度快，并且可以对所有的代码进行内存分析
缺点：分析结果不一定准确（没有运行程序，根据代码的上下文语法结构）
注意：如果有提示有内存泄露，一定结合代码查看代码是否有问题

>2、动态内存分析(Profile => Instruments=>leaks)

真正运行程序，对程序进行内存分析（查看内存分配情况、内存泄露）
优点：分析非常准确，如果发现有提示内存泄露，基本可以断定代码问题
缺点：分析效率低（真正运行了一段代码，才能对该代码进行内存分析）
注意点：如果发现有内存泄露，基本需要修改代码（基本有内泄露）

>Time Profiler

CPU使用，运行时间

#### 界面调试工具Reveal


