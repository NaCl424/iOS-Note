## Basic for developing iOS

### 1、What‘s it Object、Class、MetaClass、Category in Objective-C?

Class其实是一个`struct objc_class *`指针，它继承自`objc_object`结构体。`objc_object`结构提里面也有一个`isa`指针。

`struct objc_class`里面还有以下内容：一个指向MetaClass的`isa`指针，同时包含`super_class`指针，`cache`和`class_data_bits_t`类型的bits。

其中`isa`指针它其实是一个`union`，里面isa_t类型、Class类型、bits公用64位内存。其中bits相当于是整个union的内存位。比如要通过isa去取mateClass，其中index=0的时候，Class指向的就是MetaClass，如果index=1，则需要去isa的结构体里面，按照shiftcls去拿。

`cache`是这个数据结构其实是一个哈希表，用于缓存方法调用过程中已经查找过的方法，key是函数名，value是函数地址(因为有继承关系，所以某个类的方法可能实现在父类中，所以会有一个查询过程)。

`bits`是类的数据，比如实例/类拥有哪些方法、实例变量、遵循哪些协议都存储在这里面，类型是`class_data_bits_t`，该结构体里面就一个64位的bits指针。它相当于class_rw_t加上rr/alloc标志，class_rw_t其实就是`class_data_bits_t`里面3到47位的数据。

类中存储的方法、属性、实现的协议都存储在`class_rw_t`结构体中，同时里面还有一个指向常量的`class_ro_t`类型的指针`ro`。`class_ro_t`中存储的是在编译时期已经确定的实例变量、方法和遵循的协议。

> 那么这两个有啥区别呢？这就要从runtime加载说起，runtime启动的时候会对类进行`realizeClass`。编译期间Class里面的`class_data_bits_t`类型的变量bits其实是执行`class_ro_t`结构体的，然后在runtime跑起来的时候，先调用`Class`里面的`data`方法(方法返回的是`class_rw_t`类型)，强制转为`class_ro_t`类型，并初始化一个`class_rw_t`结构体，这个结构体里面的`ro`指针指向`class_ro_t`，再把data赋值给Class，然后再类自己实现的方法、分类实现的方法、属性和协议加到，class_rw_t结构体里面对应的列表中存起来。

Category是一个`objc_category`的结构体，里面包含`category_name、class_name、instance_methods、class_methods、protocols`这些属性。

isa指针bit_field：

`nonpointer`: 是否是普通指针，还是存了额外信息

`has_assoc`: 是否有关联对象

`has_cxx_dtor`： 是否有C++或者Objc析构器，没有可以更快释放对象

`shiftcls`: 存储类指针的值，常见是33位

`weakly_reference`: 是否被指向，或者曾经指向弱引用，如果没有可以更快释放对象，不用查weak表了

`deallocating`: 对象是否正在释放

`has_sidetable_rc`: 是否在SideTable里面存储了引用计数。

`extra_rc`: 额外的引用计数

### 2、Message send in iOS

所有方法调用，底层其实都会转化为objc_msgSend(recevier, @selector(method), args)。其中SEL内存地址是在编译时期就确定的，相同名字的SEL不会因为Class不同而改变。objc_msgSend类似的有objc_msgSendStret、objc_msgSendSuper、objc_msgSendSuper_stret。

在走objc_msgSend后，会根据方式是否是第一个被调用，走`lookupImpOrForward`(第一次调用没有缓存)。所谓的缓存有全局的方法缓存，还有类和元类里面的方法缓存。如果第一次方法调用被正确响应了，那么之后的调用直接返回缓存中的方法，而不再走`lookupImpOrForward`。如果没有找到方法，并且该类及父类都没有实现`resolveXXXMethod`方法，则一直找到NSObject，触发方法未找到的Exception。

- 如果没有找到方法，则先会走`resovleInstanceMethod`或者`resolveClassMethod`进行方法决议，这里如果这里还是没有解决，则继续走消息转发；

- 消息转发就是`forwardingTargetForSelector`，返回一个可以处理这个@selector的对象。如果还是没解决，则继续下一步；
- 先调用`forwardInvocation:`方法，其中入参`NSInvocation`需要通过实现`methodSignatureForSelector:`，先生成方法签名，然后runtime会用这个方法签名生成对应的invoke对象，再传给forwardInvocation。这里`methodSignatureForSelector`你完全可以生成一个和原selector一点关系都没有的方法签名，然后再把这个方法签名传出去。然后第4步里面拿到的selector，还是原始的selector。

第2步可以把消息转发给一个对象，而第3步理论上可以把消息转发给多个对象。

#### 实际应用

支付SDK里面就应用了这个，实现了模块是否接入的检测。我们调用一个业务模块，首先会生成一个NEPBusinessTaskInfo对象，然后每个业务都基于这个对象用Category暴露接口。然后在NEPBusinessTaskInfo类里面，实现了`methodSignatureForSelector:`方法，方法签名是一个task_not_found方法，然后再`task_not_found`方法里面，返回一个NEPBusiness4O4TaskInfo，这样我就知道商户接没接这个模块了。

### 3、AutoreleasePool

autorelasePool其实一直在默默工作，因为我们整个应用都是在一个大的releasepool里面(见main函数)，而像`[NSArray array]`这种方式构造的对象，其实系统一直在背后默默给我们插入`[array autorelease]`这样的语句，不然他是不会被释放的。

@autoreleasepool其实是一个语法糖，它把两行代码拆出来了，一个是objc_autorelasePoolPush，一个是objc_autoreleasePoolPop()。

一个AutoreleasePoolPage对象主要包含以下内容：`magic、id *next指针、pthead_t const thread(当前Page所在线程)、AutoreleasePoolPage *parent、AutorelasePoolPage *child、depth`，因此每个autoreleasePool都是由一些AutoreleasPoolPage组成的，每个Page大小都是4KB。其中begin()方法和end()方法分别指向了每页page可以用来存储autorelease object的开头和结尾，next指向了该page可以存放内容的栈顶地址，写入内容后栈顶地址+写入内容size，每页地址都是从低地址向高地址延展。

通过parent和child可以看出来，每个AutoreleasePoolPage都是通过双向链表连接起来的。

`objc_autoreleasePoolPush`方法用于创建autoRelasePage，autorelase方法用于向page中写入object，这些object在autorelasepool被释放的时候，会依次调用release方法。同时`objc_autoreleasePoolPush`创建的第一个page，插入的第一个值其实是一个nil值，然后该函数返回的结果，其实也是这个地址。

`objc_autoreleasePoolPop`方法用于释放对应的pool对应的objects，它会传入一个地址，这个地址就是之前push的时候返回的哨兵地址，然后系统就在page双向链表里面找到这个哨兵所在的page，从hotpage一直释放到当前所在page，如果当前page是code，则更新为hot。在pop的过程中对每一个对象调用release方法。

##### 结论

1. 有一个问题，同一个对象，被多个autoreleasepool包围，那么是会造成问题的。
2. 每一个线程都会维护自己的`AutoReleasePool`，而每一个`AutoReleasePool`都会对应唯一一个线程，但是线程可以对应多个`AutoReleasePool`。
3. `AutoReleasePool`在`RunLoop`在开始迭代时做`push`操作，在`RunLoop`休眠或者迭代结束时做`pop`操作。
4. 子线程因为没有自动创建RunLoop，那么那些autoRelease对象会有内存泄露问题吗？不会因为，调用autoRelease的时候，会查找线程对应的Page，如果没有Page，则会自动帮你创建一个，并且设置为hotPage。

### 3、Retain、Release、Refrence count & Memory management

以`alloc`、`new`、`copy`、`mutableCopy`这些开头的方法，调用之后，ARC模式下，编译器会在语句调用外围自动插入retain和release，这些方法是会被标记为`__attributed((ns_returns_retained))`，而其他方法则会被标记为`__attributed((ns_returns_not_retained))`，那么这些对象，其实是系统自动帮你添加了`autorelease`调用。

引用技术有几句关键句：

- 自己生成的对象，自己持有；=>>比如alloc、new、copy、multableCopy开头的方法调用后，对象的引用计数是1；
- 非自己生成的对象，也能持有； =>>比如 [NSMutableArray arry]，这种方式生成的对象，则需要自己调用[array retain]；
- 自己不再需要持有的对象时释放； =>>比如上面两句生成的对象，需要自己调用[obj release]进行释放；
- 非自己持有的对象无法释放；=>>如果释放，就会崩溃；

Retain方法最关键的还是rootReatin方法，其中会把`isa`指针的`extra_rc`值+1。

当调用对象的relase方法时，如果extra_rc为0，并且sideTable里面值也等于0，那就释放该对象；

tagPoint的引用计数就是它本身里面，如果是Objc1.0的，则引用计数都保留在一张sideTable里面，而Objc2.0则是isa指针保存一部分，sideTable保存一部分。

weak指针原理，系统有个全局的Hash表，里面key是对象，被weak指针引用的对象，value是个数组，里面放了引用该对象的指针，当对象被释放时，遍历这些指针，同时将他们指向nil。

### 4、Runloop

iOS中的Runloop是一种事件驱动模型，和NodeJS、Flutter里面的EventLoop其实都是类似的。通常来说，一个线程执行完任务之后，该线程就会自动销毁，如果我想要线程一直存在，那么就可以写一个while循环，在while循环里面去监听各种事件，然后做出各种处理，直到while里面收到退出事件让我退出，那么我就退出，这种模型就是简单的Runloop模型。有了上面的概念，我们会发现这个Runloop需要解决的问题就包括以下两点：事件的分类和处理、线程休眠和唤醒，不然线程一直跑着对CPU资源是一种浪费。

##### 如何创建Runloop

系统并没有直接提供创建runloop的函数，系统只暴露了两个API，分别是CFRunloopGetMain()、CFRunloopGetCurrent()([NSRunloop mainRunloop]和[NSRunloop currentRunloop])方法。GetCurrentRunloop方法如果没有获取到当前线程对应的runloop，则会自动创建一个。线程和runloop是一一对应的，它们被保存在一个全局的字典里面。

##### iOS中Runloop事件分类：

1. timer事件

   timer对应CFRunLoopTimerRef，当它被加入runloop时，runloop会记下触发的时间点，当时间点倒是，timer是可以唤醒runloop的。

2. source事件

   source对应CFRunLoopSourceRef对象，Source事件有两个版本，分别为source0和source1，对应`CFRunLoopSourceContext`和`CRRunloopSourceContext1`。

   - source0只包含一个回调，它并不能主动唤醒runloop，他需要调用`CFRunLoopSourceSignal`来标记，同时该事件是支持取消的。
   - source1包含一个回调和一个mach_port，它可以主动唤醒runloop，但是该事件不支持取消。

   

3. observer事件

   observer事件包含一个回调，当runloop状态发生变化时，观察者就可以接收这个回调。支持的observer有以下几种：

   `Entry、BeforeTimers、BeforeSources、BeforeWaiting、AfterWaiting、Exit`，分别对应runloop进入、即将处理Timer、即将处理Source、即将进入休眠、即将从休眠唤醒、即将推出Runloop这6中状态。

iOS中把这些事件叫做mode item，因为这些item是被加到mode当中去的，如果Runloop的mode里面，一个item都没有，那么这个线程的while循环其实是没有意义的，所有线程会退出，runloop自然也就被销毁了。我倾向于把这些mode item理解成event。

##### iOS中runloop有一个mode的概念

mode对应NSRunloopMode/CFRunloopModeRef对象，该对象里面有一系列属性，分别为Source/Timer/Observer集合。Runloop在运行的时候，只能跑在一种mode下面，如果要切换mode，必须停止当前runloop，再重新指定mode。这个API只有CoreFoundation框架有，分别为`CFRunloopStop和CFRunLoopRunInMode`。

一个runloop它可以包含多个mode，在runloop的结构体里面，有一个set，这个set里面就包含了该runloop配置的所有mode。然后mode还有一个`common`属性，runloop本身里面就管理了一些`commonModeItems`，每当runloop发生变化时，这些items，会被自动复制并加入到那些设置了`common`属性的mode中去，这么说可能有点绕，直接看runloop结构体的声明就很容易理解。

```
struct __CFRunLoop {
	CFMutableSetRef _commonModes;
	CFMutableSetRef _commonModeItems;
	CFRunLoopModeRef _currentMode;	// 当前所运行的mode
	CFMutableSetRef _modes;
}
```

然后我们再看`CFRunLoopMode`结构，它就非常简单，里面主要是4种item的容器，加上名字，应为iOS中runloop的管理是通过名字进行的。

```
struct __CFRunLoopMode {
	CFStringRef _name;
	CFMutableSetRef _source0;
	CFMutableSetRef _source1;
	CFMutableArrayRef _timers;
	CFMutableArrayRef _observers;
}
```

iOS系统默认注册了5个Mode，分别为：

- kCFRunLoopDefaultMode：App默认的mode，通常主线程是在这个mode下工作的。
- UITrackingRunLoopMode：界面跟踪Mode，用于ScrollView追踪触摸滑动，保证界面滑动时不受其他Mode影响；
- UIInitialzationRunLooopMode: App启动时进入的第一个Mode，启动完之后不再使用。
- GSEventRecevierRunLoopMode：接受系统时间的内部Mode，看起来像是解析手势事件的，通常用不到；
- kCFRunLoopCommonModes: 内部占位Mode，没有实际作用。

主线程RunLoop里面有两个预置的Mode: `kCFRunLoopDefaultMode和UITrackingRunLoopMode`，这两个Mode都被标记为`Common`属性。App在默认情况下，添加的timer是注册到kCFRunLoopDefaultMode中去的，那么在ScrollView滚动时，这个timer事件是没有被注册的，那么就不会被触发。如何解决的思路就很明显了，有两种方式：一是手动把该timer加到UITrackingRunMode中去，另一种是将该item添加到RunLoop的commonModeItems里面去。可以通过`[[NSRunloop mainRunloop] addTimer:forMode:]`方法mode配置成`NSRunLoppCommonModes`就OK了。

##### Runloop大致流程

- 通知entry observer
- 通知timer observer
- 通知source observer
- 通知线程休眠observer
- 线程被唤醒，可能是timer、source1、也可能是dispatch唤醒，通知线程将要被唤醒observer，如果有source0事件，则直接处理source0事件，跳过sleep。
- 处理timer事件
- 处理dispatch进来的block
- 处理source1
- 如果超时、或者收到退出事件，通知observer exit，否则返回第2步。

##### Runloop内的AutoreleasePool

在Runloop中，系统添加了runloop entry 、before waiting、exit这个3个observer，当收到entry通知时，调用objc_autoReleasePoolPush，触发before waiting时，先调用objc_autoReleasePoolPop、再调用objc_autoReleasePoolPush，当触发exit时，调用objc_autoReleasePoolPop。

##### 事件的区别

手势识别是source1事件，比如点击、触摸、滑动等，系统收到source1事件后，就会唤起runloop，调用`TouchBegin、End、Cancel`这些函数。系统还注册了一些observer，用于处理guesture和UI绘制，比如识别为touch、pan等手势，都会被放到一个全局的待处理手势列表里面，调用了`setNeedDisplay和setNeedLayout`的UIView、Layer都会被丢到一个全局的视图处理列表里面，然后在收到`beforeWaiting`时，分别处理这些手势、重新布局页面。

##### 其他细节

`performSelecter`其实会在runloop内部注册一个timer，所以当前线程如果没有runloop，该方法会失效。

特别的`performSelector:onThread`，如果该线程没有创建runloop，就不会生效！其原理是因为该方法会生成一个timer，并注册到线程对应的runloop对应的mode中。

**在GCD的子线程中，如果创建一个runloop，会导致该线程无法被GCD复用！这个需要引起注意！特别是串行队列的子线程，一定不要去创建runloop，如果创建了，那么之后派发到该队列的任务，一律会被阻塞！**

在自定义NSURLProtocol的子类的时候，所有client方法，比如`NSURLProtcol:didFinishLoading:`这些方法都要和`startLoadingRequest`和`stopLoadingRequest`方法使用同一个线程，所以必须创建runloop。

### 5、What's responder chain?

>  响应者链是为UIEvent查找视图的过程，其中主要设计两个类UIResponder和UIView

UIResponder主要提供三类接口：

- 向上查询响应者的接口，主要体现在`nextResponder`这个唯一的接口；
- 用户操作的处理接口，包括`touch`、`press`、`motion`和`remote`四类事件的处理；
- 是否具有处理`action`的能力，为其查找对应的`target`的能力；

> 查找响应者实际上是查找点击坐标落点位置在其可视范围内且其具备处理事件能力的对象，即既要是responder，又要是view的对象。

总的流程分为2步，第一步为查找响应者，第二步为响应者处理事件。

查找合适的view主要依靠两个函数`hitTest:withEvent`和`pointInside:withEvent:`，查找最先是从UIWindow开始，window会先收到hitTest的调用，然后它会调用自己的`pointInside`方法，如果pointInside返回YES，则它会遍历所有子视图，依次调用他们的`hitTest`方法，然后他们的子视图在分别调用自己的`pointInside`方法，直到view没有子视图，并且自己的`pointInside`方法返回了YES，那么该view就会开始结束`hitTest`递归，并且返回自己，那么这个view就是我们所要找的合适的视图。

然后是第2步，事件的处理，上面讲到了我们找到了合适的view，但是如果该view没有实现`touchBegan、pressBegan、motionMitonBegan`这系列方法，那么就把会该event往上抛，比如给他的父视图，父视图也没实现，那么给视图控制器，依次上抛，直到UIApplicationDelegate，如果都没人实现，那么该点击事件就被抛弃了。

> 另外某个页面注册了guesture，guesture会阻断点击事件的传播，guesture其实是source0事件，而点击事件是source1事件，guesture的触发时机是beforeWaiting。然后由于注册了guesture，系统会把点击事件包装成guesture，放到runloop统一的待处理列表中，等beforeWaiting observer触发，再拿出来处理这些guesture。所以我们会看到，刚开始响应者的touchBegan会被调用，后面又会Cancel。

##### 常见应用

1. 让超出父视图的子视图部分，可以影响点击事件；
2. 覆盖在父视图上的子视图，不响应事件，让父视图响应，这个很简单，设置userInteractionEnable=NO；
3. Alpha = 0, 子视图超出父视图，userInteractionEnable = NO，hidden = YES，这些情况下，父视图不会走这些子视图的`hitTest`方法；

### 6、Block implementation

我们定义的Block经过系统编译后，会变成一个结构体，里面包含 __block_imp结构体，还有block的描述，同时还有被捕获的变量。

在__block_imp结构体里面，首先是一个isa指针，指明该block类型，同时还有一个函数指针，指向真正的代码位置。

然后系统还会把block的代码块，定义成一个函数，赋值给__block_impl结构体里面的函数指针。

##### Block变量捕获

block可以捕获的变量有局部变量，静态局部变量，全局/静态局部变量。全局变量/静态全局变量block是不会捕获的，因为在编译的函数指针所指的函数中可以正常访问这些变量。但是局部静态变量不一样，它在编译后的函数里面，无法被正常访问，那么就需要被捕获，然后在转化的函数调用参数里面，第一个就是__struct_block_imp指针，相当于对象的self，然后就可以在编译后的函数中访问/改变这个变量了。

然后如果是普通的局部变量，那么捕获的他的值，向int/string这类字面量，如果是对象，则捕获的是对象指针，同时还会按照对象指针类型加入storng、weak关键字。

如果变量前面加了__block，那么情况就比较复杂了，被捕获的变量变成了一个，Block_byref_x结构体，里面包含一个isa指针，还有一个forwarding指针，这个指针指向的block自身，如果block是栈上block，就指向它拷贝到堆上的block，如果自己本身就是一个堆上block，则指向自己。在被编译的函数中，val的赋值需要通 --forwarding指针来赋值。

Block的类型有3种，一种是Global、一种是stack、一种是malloc，如果一个block未捕获任何普通变量，那么这个block会在编译时就确定，他是放在data区的，相当于已经初始化的全局变量。

stack是定义了，但是未赋值给指针的，malloc是对stack做copy，或者赋值给block指针的，系统会自动做copy。

### 7、GCD底层线程调度原理

//TODO: 太难了，源码看不懂

### 8、卡顿优化，CPU卡顿和GPU卡顿如何避免

##### 卡顿检测方法

1、通过`CADisplayLink`计算1s内刷新次数，也可以使用Instrumetns里的Core Animation。

2、通过Runloop，实时计算`kCFRunLoopBeforeSources`和`kCFRunLoopAfterWaiting`两个状态区域之间耗时是否超过某个阀值；

3、子线程检测，每次检测时设置标记位为YES，然后异步派发到主线程，同时在主线程中，将标记位设置为NO。主线程沉睡超时阀值，判断标记位是否成功设置为NO，如果没有说明主线程发生了卡顿；

##### CPU卡顿优化

1. 对象创建
2. 对象调整
3. 对象销毁
4. 布局计算
5. Autolayout
6. 文本计算
7. 文本渲染
8. 图片解码
9. 图像绘制

##### GPU卡顿优化

1. 纹理的渲染

   所有的`Bitmap`，包括图片、文本、栅格化的内容，最终都要从内存提交到显存，绑定未GPU纹理；当短时间内显示大量图片时，CPU占用率低，GPU占用率高，因此会导致界面掉帧。解决方式将图片合并为一张进行显示；

2. 视图的混合

   减少视图层级，不透明视图`opaque`设置为YES，避免`alpha`通道合成；

3. 图形的生成，比如`Border、圆角、阴影、mask`等操作；

##### 原生渲染卡顿优化方案

- 尽量用轻量级的对象，如：不用处理事件的UI用CALayer等；
- 不要频繁调整UIView的相关布局属性，比如frame、bounds、transform等
- 尽量提前计算号布局，在有需要的时候一次性调整完毕，避免多次修改；
- 图片的size尽量和UIImageView的size保持一致；
- 控制线程的最大并发数量；
- 耗时操作放入子线程：比如文本的尺寸计算、绘制，图片的解码、绘制等
- 尽量避免短时间内大量图片的显示；
- 控制纹理尺寸；
- 尽量减少视图数量和层次；
- 减少透明的视图，不透明值设置为YES；
- 尽量避免离屏渲染；

##### ASDK作用

1. Layout

   文本宽高计算、视图布局计算

2. Rendering

   文本渲染、图片解码、图形绘制

3. UIKit Objects

   对象创建、对象调整、对象销毁

这些操作放到后台线程进行，避免阻塞主线程。

### 9、KVC底层实现

KVC是一个非正式的Protocol，用途完全不一样，它提供了一种使用字符串去访问对象属性的机制，而不是通过geter和setter方法。

首先如果调用setValue:forKey:，则会依次查找setKey和_setKey方法，然后看是否支持直接访问对象属性，如果可以，查找key、下换线key这些，如果找到直接调用。

大概就是这么个过程。

### 10、KVO底层实现

当你监听一个对象的时候，系统会动态的生成一个NSKVONotifyin_xxxx队形，然后让原来的对象isa指针指向这个动态生成的对象，同时，让这个NSKVONotifyin对象的rsa指针，指向原来的那个objc_class结构体。同时这个NSKVONotifyin_xxx对象，会重写setYYY方法，就是你监听的那个属性，在set方法里面，会调用`_NSsetIntValueAndNotify`，这个C方法的本质是先调用`willChangeValueForKey`，然后调用原来那个类的setYYY方法，然后再调用`didChangeValueForKey`方法。同时这个NSKVONotifyin_xxx还重写了Class方法，为了伪装。类似的方法我们在做网络请求白屏检测，还有网络请求性能监控的时候都有用到。

didChangeValueForKey方法里面会调用`observerValueForKeyPath:ofObject:change:context:`。

如果想要手动触发，也是很简单的，在设置属性之前调用`willChangeValueForKey`，在设置属性之后`didChangeValueForKey`。

KVO接收通知的方法里面，如果调用UI更新要小心，因为可能是子线程；还有一个是对keypath多次移除，特别是存在继承关系的时候，要小心；

### 11、关联对象(AssociatedObject)底层实现

关联对象提供了5种存储策略，分别是:assign、retain_nonatomic、copy_nonatomic、retain、copy。

AssociationManager是管理关联对象的入口，也是一个单例，它内部存在一个spinlock和AssociationsHashMap实例，spinlock是用来保证内部hashMap数据线程安全的。在这个HashMap里面存的内容是，key为关联对象的指针(`DISGUISE宏定义获取`)，值对应的是一个ObjectAssociationMap。然后这个ObjectAssociationMap里面放的key就是我们在调用`setAssociatedOjbect`连传个key，值就是我们要关联对象保存的值。

其中还有一个`setHasAssociatedObjects`方法，该方法会在关联对象的isa指针里面的，打开有没有关联对象的标志位。为什么要设置这个标志位呢？那就是我们在调用`obcj_removeAssociatedObjects`方法时，先检查该标志位，如果没有，则避免不必要的方法调用，已提高性能。

另一个作用是，这个关联对象被释放的时候，要来AssociationHashMap中释放，这个关联对象所关联的所有值。

另外这个实现有一个值的学习的点是，manager并不是单例，它使用的是一个静态锁和静态HashMap，每次manager实例init的时候用全锁去加锁，manager析构的时候全局锁解锁，这样可以减少manager这个对象在内存中常驻，是一个非常细节的优化手段。

### 12、nonatomic和atomic有啥区别？

nonatomic是非原子性，atomic是原子性，atomic可以保证property的getter和setter方法调用不会出现数据竞争，但是对于像NSMutableArray这样的对象，设置atmoic毛用没有，因为可变数组不安全的是它作为容器，而不是它自身。

另外一个是如果设置有atomic，但是又重写了set/get方法，那也是没效果的。

像weak,strong, assign是直接作用在变量上的，atomic、copy就是作用在getter/setter方法上的。

### 13、strong和copy有啥区别？

strong是作用在property对应的变量上的，copy是作用在getter方法上的，在调用getter的时候跑一次copy。

然后strong修饰的对象，可能会被改写，比如strong修饰的NSString，而copy修饰的字符串则不存在这个问题。

### 14、What's different between ivar and property?

ivar是类的实例变量，property其实是一个语法糖，在类和extension中，可以为你自动生成成员变量，以及对应成员变量的getter/setter方法

### 15、setNeedsDisplay和setNeedsLayout有啥区别？

setNeedsDisplay的视图对象，会在下一个runloop beforeWaiting通知到来时，调用CALayer的`display`(UIView的drawRect)

setNeedsLayout的视图对象，会在下一个runloop beforeWaiting通知到来时，调用CAlayer的layoutSublayers(UIView的layoutSubviews)

### 16、什么是toll-free bridged？

__bridge进行OC和CF指针之间的类型转换，同时不改变原有对象生命周期所有权，比如

从OC转成CF，CFStringRef cf_str = (__bridge CFStringRef)str; 那么CF不用释放

从CF转成OC，NSString *str = (__bridge NSString *)cf_str，那么还是要对cf_str进行释放。

这个常用在转换后当成方法入参使用，比如我有一个NSString对象，但是要调用的方法需要一个CFStringRef，这时候就比较适合使用__bridge

__bridge_retained 将一个OC指针转成CF指针，同时移交所有权，也就意味着所有权来到了CoreFoundation这边，那就需要手动释放内存！

__bridge_tansfer 将一个CF指针转成OC指针，同时移交所有权给ARC，也就意味原CF变量不再需要释放！

### 17、HashMap底层实现？

NSDictionary底层的实现应该是CFDictionary，也就是我们经常再说的HashMap。

哈希表的keys一般是一个数组，而hash一般是一个非负整数，可以通过对hash取模，确定它在数组中的索引，但是不同的key会存在索引一致的情况，就是我们说的hash冲突，这种情况出现，一般会有2种解决方法。

1. 拉链法

   拉链法当中，当确定index之后，存值的其实是一个链表，同时每个节点保存了源数据的key和value，当冲突时，就从头开始遍历链表，比对完整的key，找到了就返回value。这种方式效率较低，很难做到时间复杂O(1)；

2. key数组扩容问题

   负载因子 = 总键值对数 / 数组的个数，随着数据量的增加，存放key取模的那个数组，很容易放满，这时候就可以设置一个阀值，当到达阀值的时候，扩充它的结构，比如原来取模的底是20，那么我们就可以扩容到40，然后重新计算里面元素的key对应的新值。后面加进来的新值，就会因为模数的变换而变化。

3. 开放定址线性探测

   使用两个大小为N的数组，一个存放keys，一个存放values，当key的hash相同发生碰撞时，直接将下标索引加1，向后寻找，然后知道找到空位，没有就从头开始找，然后key的hash值存到keys数组，value的值存到values数组。

### 18、什么是离屏渲染？如何避免？

离屏渲染的意思是，普通情况下，我们屏幕上的画面是从frameBuffer取的，但是有时候，frameBuffer没法一次性直接渲染好完整的内容，需要额外的内存空间来协助，这种情况就是离屏渲染。这里就设计到一个画家算法，每帧渲染的时候，都是从原到进开始渲染，当某一层画完，但是需要回过头擦除、修改某一部分的时候，就需要额外的空间，来临时存储某一层数据。比如某个子视图画上去之后，发现父视图有圆角，那么子视图也要跟着裁剪，这个裁剪动作就需要额外的缓存空间。

iOS调试器其实是有地方可以直接看到离屏渲染的。

单纯的设置圆角+裁剪，并不会导致离屏渲染。但是如果父视图设置的圆角，那么子视图有内容，才会触发离屏渲染。所以关键是搞懂是不是在图层合并的时候，需要做裁剪。

然后是shadow会触发、mask会触发、UIBlurEffect毛玻璃效果。

还有shouldRasterize，这个属性的本意是降低性能损失，通过离屏渲染结果复用，但是还是有诸多限制。

1. 直接让设计提供带阴影和圆角图片；
2. 通过CoreGraphics框架做异步渲染，占用CPU资源，渲染完成回传回主线程使用；
3. 阴影使用shadowPath来实现；
4. 合理使用ASDK做渲染框架，特别是文字和图片部分；

### 19、多线程相关

1. async和sync区别

async不会阻塞当前线程，不会等待任务完成。sync会阻塞当前线程，同时会等待任务完成。

2. GCD和NSOperation的区别
   1. GCD仅支持FIFO队列，NSOperation可以自定义优先级，调整任务队列执行顺序；
   2. NSOpeation支持KVO，可以观察任务执行的状态；
   3. NSOperation支持cancel，而GCD不支持；
   4. GCD性能更好；

3. 常见的锁，底层实现，可能存在的问题？

   互斥锁: @sychronized、NSLock 闲等锁，阻塞当前线程，然后休眠

   递归锁: NSRecursiveLock，用于解决NSLock在递归的过程中，多次调用lock方法导致死锁；

   条件锁: NSConditionLock、pthread_cond_t，常用于处理生产者/消费者(I/O)问题，还有哲学家吃饭问题；

   信号量: dispatch_semaphore

   OSSpinLock、os_unfair_lock: 自旋锁，忙等锁，阻塞当前线程，

   这种都有的锁: pthead_mutex_t，他可以指定多种类型，最常见的是NP，缺省值的表现和NSLock相同


4. 常见用来解决多线程数据竞争的手段？

   @synchronized、NSLock、NSConditionLock、NSRecursiveLock、dispatch_barrier、dispatch_semaphore_t、pthread_mutex_t、pthread_cond_t、os_unfair_lock

   

5. NSOperation常见应用

   // TODO

   

6. 实际解决过的问题

   1. 单例上面的多线程数据竞争，导致App崩溃，堆栈看起来某个函数递归调了很多遍，定位相关单例；

   2. 白屏检测、网络请求录制、播放、网络请求性能监控这些框架都大量涉及多线程的问题；

   3. 使用dispatch_semaphore，常见有3种用法。

      第1种当NSLock用，创建1个信号量(单例或者init方法)，代码块前面放一个semaphore_wait，后面跟一块代码块，代码块结束放一个semaphore_signal；

      第2种做异步切同步，比如你想拿一个数据，这个数据是异步调用的，通过complete block去拿结果，但是你又想像同步的方式把结果返回出去，这时候就是创建一个semaphore值为0，然后调用接口，异步接口里面发送signal，异步调用接口的下面设置semaphore_wait，然后里面拿到结果后，赋值给__block修饰的变量，最后返回这变量。

      第3种用作类似线程池的效果，比如初始化一个semaphore，初始信号量为5，然后没用一次调用一次wait，任务做完调一次signal。

   4. dispatch_barrier，这个的话虽然说性能比较差，但是在那种并发读取，及小量写入的时候，我觉得是很合适的，比如我写的网络请求录制里面，一般配置只设置一次，但是后面都是读，这种用栅栏效果就很好了。

### 20、线程池

1. 通过dispatch_sema + 信号量数量，来模拟创建线程池
2. 通过N个串行队列，来模拟线程池；
3. 通过pthread来实现线程池；
4. 通过NSThread + runloop来实现线程池；

### 21、bitcode的理解和作用

开启bitcode的后，App提交给Apple是经过编译的中间码，Apple存在在分发到AppStore之前，就行编译和链接优化的可能。这个和包大小没有什么关系。

### 22、静态库和动态库的区别

静态库是会在App编译的时候，会被完全打进可执行文件里面的，而动态库则不一样，是在启动时候动态链接的。iOS中目前不支持dlopen，那么所谓的动态库叫做embbered动态库，可以用于主应用和扩展应用之间公用。

静态库是每次App启动都会随应用启动而载入内存，动态库则只载入一次(系统动态库)。

看.a和.framework去鉴别是不对的。

静态库和动态库都建议用.framework，因为支持bundles。

还有一个XCFramework，这个还没怎么了解过。

### 23、组件化的理解和市面上常见的组件化方案

目前主流的组件化方案由URL路由、target-action、protocol匹配。

##### URL-block方式，通过URL定义每个页面/业务，特点是

1. 需要维护一个中心化的字典，里面存了url对应的Class，
2. 通过runtime去实例化调用到的页面对象。
3. 参数传递可以通过url去传递，也可以通过扩展路由接口，传自定义的字典；

我觉得比较适合小团队，因为存在较多的硬编码和参数；

##### Protocol方式

1. 接口类似代码，接口即定义，可以定义函数、block等；
2. 不再硬编码，比较规范；

我个人比较倾向的方案；

启动时向ProtocolManager注册，中心化思想。

##### Target-Action方案

这个方案我不怎么熟悉，也没有实践经验，大概看过，首先感觉太灵活了，runtime编译阶段不检查，运行时才检查对应类或者方法是否存在，感觉很容出问题，不太适合大团队合作使用；

### 24、MVVM、MVC架构区别

主要是逻辑代码的组织方式不同，MVC是有controller控制model和view，而MVVM则由controller持有ViewModel，而ViewModel持有mode，view直接KVO viewModel的属性，理论上来说vm的属性，必须直接反应页面元素可以直接使用的结果，然后逻辑隐藏到VM中。那其实MVC也可以实现类似的逻辑，比如通过充血model的方式，转移部分展示切换逻辑。但是MVC当中请求可能还是需要放到Controller中去做。

### 25、工具链CocoaPods相关问题



### 26、LRU算法

使用哈希表+双向链表实现，哈希表key为存储值key，value为DLinkNode，DLinkNode里面不仅要存储val，也要存储key，方便找到节点之后删除。

### 27、iOS应用安全防护

1. 越狱判断

   判断设备是否越狱，通过NSFileManager去判断设备是否已经越狱，判断指定目录是否存在，比如`/Application/Cydin`、`/usr/sbin/sshd`、`/bin/bash`。

   如果攻击者HOOK了FileManager函数，则需要通过C的`stat`函数判断是否存在该文件。

   攻击者还可能使用fishhook替换`stat`函数，我们可以先判断stat函数来源，如果是fishhook的stat函数，他的来源将指向注入者的动态库，这样检测到非系统库，则直接返回越狱。

   通过环境变量DYLD_INSERT_LIBRARIES来判断是否越狱，若获取到的为NULL，则未越狱，同样的如果攻击者通过fishhook做方法替换，我们可以用上面的方法检测。

2. 检测非法注入的动态库

   通过遍历dyld_image可以检测非法注入的动态库，非法注入的动态库是`/var/containers/Bunlde/Application`同时是`.dylib`结尾的。

3. 关键函数hook检测、阻止hook、hook白名单

   创建一个自己的的动态库，然后在load方法里面进行防护。在攻击者进行fishhook之前，我们先hook`method_changeImplementation`和`method_setImplementation`，然后在里面监听所有的方法交换。一旦遇到我们不想被用户交换的方法，就可以阻止重要的方法被hook。

4. BundleID检查

   可以通过`getenv("XPC_SERVICE_NAME")`来获取BundleID

5. 字符串加密和混淆

6. 通过判断目录下面是否存在`embedded.mobileprovision`文件，如果存在那么就是被二次打包的。

### 28、App签名 & 重签名

首先要搞懂数字签名的原理，本质是TSL证书签发，验证的原理，剩下easy。

1. 本机Mac上生成一个certificate.request文件，这个文件里面包含了一个公钥和一些申请者的个人信息，然后Apple用它的私钥签名生成开发者证书，这个证书里面就包含了一个签名，类似于HTTPS证书颁发的过程。所以开发机上有一个私钥L和公钥L，开发设备上有Apple的公钥A，Apple的服务器上有Apple的私钥A。
2. 然后你的App编译完成后，会用你的私钥对整个iPA包做签名，签名后的内容和iPA包放一块，然后安装到设备之后，设备用它的公钥A先验证证书是否合法，如果合法，拿出证书里面的公钥L，对iPA包数字签名做校验，如果验证OK，就认为是一个合法的包；但是这样还有一个问题，所有合法证书打出来的包，可以往任意设备上安装。
3. Apple搞了一个provision file，这里面包含了证书、Apple ID、bundileID、可测试列表这些内容(开发证书)，然后如果App启用了一些push、pay这些东西，都会放到一个叫做entitlements的文件，在生成provision file文件的时候，apple会把这些东西都使用Apple的私钥A进行签名，这样就保证了内容是受Apple控制的，并且ipa包可安装设备这些都被限制了。
4. 真正打包的时候，会把app签名、provision file一起打进ipa包里面，生成一个叫做embedded.mobileprovision文件，提交到AppStore之后，App会先对该文件做校验，校验通过，则会删除该文件，同时对ipa包使用Apple的私钥重新做签名，生成ipa包后在AppStore发放。这边Apple还会对二进制可执行文件做一些加密操作，就是加壳的意思，后面如果我们下载到加密的app包，需要先砸壳。

企业证书签名，企业证书签名的流程就是到提交AppStore之前为止，那么按照上面的流程，为啥还有用户点击信任一下证书呢？其实这个过程，会有一个网络请求的过程，比如A企业证书被Apple吊销了，但是它打包生成的证书里面的数字签名，其实还是可以用Apple的公钥A验证通过的，因为数字证书一旦签发，只要在有效期内，它就是有效的。本地设备没法直接区分该企业证书是否被吊销，只有发到Apple那边去查询，如果查询发现被吊销了，那么这个企业证书签名的App也就没法用了。

另外签名主要有三种，一种是资源文件签名，放在 `_Codesignature`下面，一种是代码签名，放在Mach-O里面，里面有一个`Code Signature`分段，然后embedded.provision文件是对apple id、entitlements这些的签名。

##### 重签名

重签名就是用合法的证书，对mobileprovision文件、所有可执行文件和frameworks重新做数字签名。

### 29、View渲染过程

iOS视图渲染的核心框架是Core Animation，渲染层次依次为: `图层树->呈现树->渲染树`。

##### 1、CPU阶段

- 布局(Frame)
- 显示(Core Graphics)
- 准备(QuartzCore/CoreAnimation)
- 通过IPC提交(打包好的图层树及动画属性)

##### 3、GPU阶段

- 接收提交的纹理(Texture)和顶点描述(三角形)
- 应用变换(Transform)
- 合并渲染(离屏渲染等)

CoreAnimation在RunLoop中注册了一个Observer，监听了BeforeWaiting和Exit事件。当一个触摸事件到来时，Runloop被唤醒，App会执行一些操作，比如调整视图层级，设置UIView的frame，修改CALayer的透明度等。这些操作都会被CALayer捕获并通过CATransaction提交到一个中间态去。当Runloop将要进入休眠的时候，之前注册的Observer就会收到回调，然后把所有中间状态合并提交到GPU去显示，如果此处有动画，CA会通过DisplayLink等机制多次触发相关流程。

##### UIView 和 CALayer的区别

- 每个UIView都有一个关联图层，即CALayer；
- CALayer有一个可选的delegate属性，实现了`CALayerDelegate`协议。UIView做为CALayer的代理实现了`CALayerDelegate`协议；
- 当需要重绘时，即调用`-drawRect:`，CALayer请求其代理给予一个寄宿图来显示；
- CALayer首先会尝试调用`-displayLayer:`方法，此时代理可以直接设置contents属性；
- 如果代理没有实现`-displayLayer:`方法，CALayer则会尝试调用`-drawLayer:inContext:`方法。在调用该方法前，CALayer会创建一个空的寄宿图和一个CoreGraphics绘制上下文，为绘制寄宿图做准备，做为ctx参数传入；
- 最后，由Core Graphics绘制生成寄宿图并存入`backing store`；
- 当操作UI时，比如改变Frame、更新了UIView、CALayer的层次时，或者手动调用了UIView/CALayer的`setNeedsLayout/setNeedsDisplay`方法后，在此过程中app需要更新View tree，相对应的Layer tree也会被更新;
- CPU计算需要显示的内容，包括Layout(布局计算)、视图绘制(Display)、图片解码(Prepare)。当runloop将要进入`BeforeWatiting`时，会通知注册的监听，然后对图层操作打包成`CATransaction`，通过IPC提交给Rander Server。
- RenderServer收到数据后，将LayerTree转成RenderTree，最后将信息传给Metal。

#### OpenGL渲染过程

输入顶点数据，顶点着色器(Vertex Shader)->图元装配(Shape Assembly)->几何着色器(Geometry Shader)->光栅化(Rasterization)->片段着色器(Fragment Shader)->测试和混合(Tests and Blending)

其中可编程的部分有3个阶段，分别为顶点着色器、几何着色器、片段着色器三个阶段。

- 顶点数组对象，Vertext Array Object，VAO
- 顶点缓冲对象，Vertex Buffer Object，VBO
- 索引缓冲对象，Element Buffer Object，EBO 或者是 Index Buffer Object，IBO

### 30、崩溃检测原理

1. 可以通过注册`NSSetUncaughtExceptionHandler`来实现OC层面异常的捕获；
2. 可以通过`sigaction`函数注册信号捕获回调，`sigaction`第二个参数为NULL，第三个参数传入`struct sigaction`结构体可以拿到原来注册的handler，然后保存之后，注册自己的handler；

##### 常见信号

1. SISHUP

   一般是terminal退出会发送；

2. SIGINT

   用户键入`Ctrl+C`发出，用于通知前台进程终止进程；

3. SIGQUIT

   和SIGINT类似；

4. SIGILL

   执行了非法指令，通常是可执行文件本身出现错误，或者视图执行数据段、堆栈溢出等错误；

5. SIGABRT

   调用abort函数生成的信号；

6. SIGTRAP

   由断点指令和其他trap指令产生，用于debugger；

7. SIGBUS

   非法地址，包括内存地址对齐出错。比如访问一个4个字节长的整数，但是其地址不是4的倍数。它与SIGSEGV的区别是后者常由于对合法存储地址的非法访问触发。

8. SIGFPE

   在发生致命算术运算时发出，不仅包括浮点运算错误，还包括溢出及除数为0等其他所有的算术错误；

9. SIGKILL

   立即结束程序的运行，该信号不能被阻塞、处理和忽略。

10. SIGSEGV

    试图访问未分配给自己的内存，或者试图往没有写权限的内存地址写数据。

11. SIGPIPE

    管道破裂，这个信号通常在进程间通信产生。比如采用FIFO通信的两个进程，度管道没打开或者意外终止，就往写管道写。

12. SIGTERM

    程序结束信号，与SIGKILL不同的是，该信号可以被阻塞和处理。通常用来要求程序自己正常退出。一般进程终止不了，我们才会尝试SIGKILL。

13. SIGSYS

    非法的系统调用；

##### 信号小tip

debug模式下，如果触发了signal崩溃，需要在lldb下，输入`pro hand -p true -s false SIGABRT`，最后的`SIGABRT`替换成真正触发的信号；





## 计算机基础

### 1、栈内存结构、堆栈区别、App整体内存分布、内存压缩技术，malloc内存分配策略

##### App整体内存分布

进程内存结构，主要分为5块，从低地址到高地址分别为：Text段(代码段)、Data段(已初始化的全局变量、静态变量、常量(比如字符串常量))、BSS段(未初始化的全局变量)、堆、栈。
其中TEXT、DATA、BSS段在编译器已经确定，得益于虚拟地址，这些地址的范围为0x000000000000000~0xFFFFFFFFFFFFFFFF，这些内存单元由Memory Management Util管理。

|  栈  | 高地址

|  堆  |

| BSS  |

| DATA |

| TEXT | 低地址

然后其实高地址上面还有预留的内核内存地址，里面有分两块，一块是每个进程都相同的物理内存、内核代码和数据，更上面的是与进程相关的数据结构，然后TEXT段一般也不会直接从0x16个0开始，而是会有一段预留空间。

保护了每个进程的地址空间、简化了内存管理、利用硬盘空间拓展了内存空间。

iOS中有Tagged Pointer，用来节约内存，比如NSNumber和NSData，它们不在是指向堆内存的指针了，它变成了前面是特殊标记，后面是真实值的结构，就是说放在栈上了。

iOS中缓存最好用NSCache，因为它在内存压缩的情况下，做了优化，而且线程安全。

##### 内存压缩策略

iOS中存在内存压缩技术，而且iOS中没有使用swap技术，所谓swap技术，就是将内存的数据写入磁盘。

所谓内存压缩技术，就是将dirty内存压缩。所谓dirty内存，就是非clear内存的部分，clear内存是指能被重新创建的内存，它主要包括以下几类：

app的二进制可执行文件、framework中的_DATA_CONST 段、文件映射的内存、未写入数据的内存。

这里可以讲内存双引用表。

##### 程序调用过程中栈的演变、栈帧结构

// TODO: 重新看这个部分，然后复习下fish hook源码。

##### 堆栈区别

栈由系统自己控制，不需要程序员接入，堆内存需要程序员自己控制，需要程序员自己申请和释放，堆内存经常用链表来表示。

##### 应用开发内存问题，一个是循环引用，一个是OOM

然后就是考察引用计数机制、循环引用等

OOM主要考虑腾讯开源的OOMDetector，它可以检查的OC和C++的OOM，Facebook出品的`FBAllocationTracker`通过hook`alloc`方法来进行内存OOM检测。

OOMDetector通过hook系统底层的`malloc_zone`和`vm_allocate`相关方法，跟踪并记录进程中每个对象对象的分配信息，包括分配堆栈、累计分配次数、累计分配内存等。

mmap优势：

1. 节省接入磁盘，需要从用户态拷贝到内核态，然后再写入磁盘的过程，直接把磁盘文件映射到内存中；
2. 写入时机有3个，一个是系统内存不足时，一个是进程crash时，一个是主动调用msync时，特别适用于日志系统；

### 2、计算机网络7层结构，TCP连接过程，TCP和UDP区别，滑动窗口机制

物理层、数据链路层(常见ARP)、网络层(IP)、传输层(TCP/UDP)、会话层、表示层、应用层(HTTP/SMTP/FTP/DNS/Telnet)

TCP连接3次握手、4次挥手，这个只能简单描述

滑动窗口机制：

简单的停等协议，发送方发包、接收方收包，接收方发送ACK，发送方收到，一次发送完成，整个过程中总有一方在等待，信道利用率低。

发送方包分4个状态：已发送已确认，已发送未确认，已缓存可发送，未缓存不可发送

发送方窗口大小 = 已发送未确认 + 已缓存可发送

接收方包分3个状态：已接收已发送ACK但是上层应用未处理，已接收未发送ACK，空的缓存区大小

##### TCP长连接和短连接

长连接：

建立连接-传输数据-保持连接-数据传输-关闭连接

短连接：

建立连接-数据传输-关闭连接-建立连接-数据传输-关闭连接

长连接的优势，省去TCP建立和连接的操作，节约资源和时间，适合大规模数据传输，但是可能被客户端瞎搞拖累；

短连接的优势是服务端管理较为简单，存在的连接都是有用的连接，不需要额外的控制手段，但是频繁的创建连接、关闭连接消耗资源；

### 3、编译过程和原理

iOS编译总的来说分3层，第1层是Clang前端编译生成IR中间码，第2层是LLVM Optimizer优化层，会根据机器相关做代码优化，生成经过优化后的LLVM IR，第3层是LLVM Bankend编译后端，生成各种平台的机器码。

其中Clang前端编译过程主要包括以下几步：

1. 预处理阶段：符号化、宏定义头文件的展开；
2. 语法语义分析阶段：将符号化的内容转成一颗解析树、解析树做语义分析，生成一颗抽象语法树
3. 生成代码：将抽象语法书转为中间码LLVM IR

然后是LLVM Optimizere阶段：

1. 将LLVM IR做优化，输出优化后的LLVM IR

最后是LLVM后端编译，该过程主要包括以下几步:

1. 编译阶段，生成目标平台的汇编代码，比如hello.s
2. 汇编阶段，输入汇编代码，汇编器生成目标文件，hello.o
3. 链接阶段，将目标文件链接成可执行文件。

传统的Unix程序编译主要包括以下几步：

1. 预处理阶段，输入源文件hello.c，展开宏定义、头文件，输出hello.i
2. 编译阶段，输入hello.i，经过语义语法分析，生成AST，然后编译生成汇编文件，hello.s
3. 汇编阶段，输入hello.s，生成目标文件hello.o
4. 链接阶段，输入hello.o，装配链接生成可执行文件hello

`nm`和`otool`是经常用的命令

比如`nm -nm File1.o`可以看到其符号信息

`otool -L a.out`可以看到其所需的库

`xcrun otool -L /System/Library/Frameworks/Foundation.framework/Foundation`

可以看到Foundation的关联库。

##### 应用启动过程

1. 加载可执行文件；
2. 加载动态链接库，进行rebase指针调整和bind符号绑定；
3. Objc运行时加载，包括Objc相关类的加载等；
4. 初始化，包括执行+load()，attribute(constructor)修饰的函数调用、创建C++静态全局变量；
5. 执行main函数；
6. 首页界面渲染；

### 4、HTTPS连接过程，防抓包，证书链

简单

### 5、加密相关内容，对称加密不同模式区别，DH秘钥交换算法

简单

### 6、六大设计原则

- SRP，单一职责原则
- OCP，开闭原则
- LSP，里氏替换原则
- LOD，最少知道原则
- ISP，接口分离原则
- DIP，依赖倒置原则

## Project experience

### 1、Hybrid and Web container

#### 大的方向上来说，hybrid实现方式有三类。

1. 通过url拦截的方式，iOS和Android都通用，JSBridge注入方式，WKUserController注入，userController可以追加自定义脚本，然后通过iframe触发一个特殊的scheme，比如"epaysdk://hybrid+uuid"，然后本地拦截到之后，再通过Web容器调用JS，获取对应的hybrid接口及参数；
2. 是通过`alertMessage`和`WKScriptMessage`，iOS和Android都通用，但是只支持`WKWebView`，js端通过调用`window.webkit.messageHandlers.handleJSMessage.postMessage`，其中messageHandlers是一个object，WKWebView可以通过`userController`添加自定义的`scriptMessageHandler`，这样就会调用到WK代理方法`userController:didRecevieScriptMessage:`，解析对应的`WKScriptMessage`对象就可以了，里面有调用的方法，参数等。
3. 通过JavaScriptCore框架，JavaScriptCore框架比较特殊，可以直接向`JsContext`对象上面挂载方法，然后JS就可以调用这个方法。JSContext实例，通过KVC方式`documentView.webView.mainFrame.javaScriptContext`获取。但是只有在UIWebView上可以拿到JSContext对象，WKWebView上webView实例和JsContext对象没法关联，因此不考虑这种方案了。

其实从某种意义上来说，bridge不仅能提供桥能力，还能向JS提供当前WebView的运行环境信息，比如我可以把当前App/SDK的版本，UA，系统版本什么的，都可以往注入的JSBridge对象上去写，然后前端就可以去约定好的JSBridge对象上去拿这些东西。因为Web容器注入JSBridge的时候，就是读取本地的JS文件内容，再传给UserController的，完全可以在这个内容里面添加逻辑和内容的。

#### Native接口模块化设计

​	收到JS侧调用后，转发给单例对象`JSCommandRouter`，router对外暴露了一个注册接口，所有业务Command在load方法里面向Router进行注册，注册key为hybrid接口名，值为业务接口Class类型。所有支持的Hybrid接口都是基于`BaseCommand`，具体业务Command继承自BaseCommand，并且实现了BaseCommand定义的一些方法，比如`initWithWebView:params:`方法，还有`doCheckAndParse`、`doBusiness`、`doFinish`方法。在`doFinish`里面再调用`Router`的`callbackToWebView:result:`方法。这边每个Command的实例，都是通过关联对象(AssociatedObject)和webView做关联的，这样Router里面是不用持有/管理这些command实例的，每次调用都只负责初始化就OK，webView释放了所有command实例也就自动被释放了。

#### 主要遇到的坑

1. Cookie同步问题

   > UIWebView使用的NSHTTPCookieStorage管理Cookie，但是WKWebView是独自管理内存的。早起由于纪要支持UIWebView又要支持WKWebView，而由于NSHTTPCookieStorage是iOS系统NSURL系统的一部分，所有NSURLSession发的请求，里面的cookie都会自动同步到Storage，同时往NSHTTPCookieStorage里面存写Cookie是同步，且几乎实时生效的。因此，主要问题是如何把NSHTTPCookieStorage里面的Cookie同步到WKWebView。

   解决方法：

   a. 在loadRequest的时候，把cookie手动写到header中，保证第一个请求的不带Cookie的问题。

   b. 在WKWebView初始化的时候，通过UserScript，注入一段document.cookie脚本，这样Web容器里面就会带上Cookie；

   c. 跨域302跳转问题，如果WKWebView加载的url是a域的，返回的response的HTTP status code是302，同时跳转的是b域的，那么b域就会丢失cookie，这个问题可以在WKWebView的`decidePolicyForNavigationResponse`代理方法中，拿出`HTTPResponse`，解析里面的header，拿出里面的location，重新封装request，再head里面加上cookie加载。

   d. Cookie过期问题，我们Cookie过期时间是12小时，如果用户开着应用放后台，第二天再打开网页，不去置换Cookie，网页就会要求用户重新登录，这种情况通过，从后台唤起后，比对内存中Cookie的有效期(Cookie拉取成功记录10小时过期)，然后重新从后台置换Cookie并重新注入，由于这是一个异步过程，所以loadRequest可能会有较长时间的白屏；

   e. WKWebView中收到的response的header中，如果有setCookie，需要把这些Cookie全部手动同步到NSHTTPCookieStorage；

   f. 不同的WKWebView实例之间，需要共享相同静态的ProcessPool实例，这样可以实现不同WKWebView实例之间的Cookie的共享；

   g. iOS11以上系统，使用WKWebView的`websiteDataStore.httpCookieStore`可以设置Cookie，但是在iOS11上面有坑，系统的`WKHTTPCookieStore`对象提供的`setCookie:completeHandler`方法有可能不会回调，然后导致页面白屏，解决方法是加一个0.1秒的延时就OK。

   

   > 然后是Cookie清理，因为我们App支持账号切换功能，切换账号之后，需要清除上一个账号的Cookie，163.com下面的NTESCookie，然后注入新账号的Cookie。

   a. 需要清理NSHTTPCookieStorage里面的Cookie，这个比较简单拿出所有Cookie，找到domain对应的Cookie，只设置为nil字符串就OK。

   b. WKWebView则需要让共享的processPool对象重新构造(设置成nil不行)，同时iOS 9以上，通过`WKWebsiteDataStore`删除WKWebsiteDataTypeCookie和DiskCache及MemoryCache，iOS 9以下，则删除Library目录下面`Cookies`目录。

   


2. UserAgent问题

   a. 往NSUserDefault设置全局Cookie；

   b. iOS 9.0以上通过`webView.customUserAgent`Cookie设置。

   c. iOS12上，调用`evaluateJavaScript:@"navigator.userAgent"`去设置UserAgent，必须用一个临时的WKWebView实例去做，不然存在UA无法正确被设置的BUG；

   

3. 大量兼容性问题

   a. JS调用`window.open`需要实现delegate方法`createWebViewWithConfiguration:forNavigationAction:windowFeatures`方法

   b. Alert/Prompt/Confirm这些都要实现delegate方法，还有web view触发了alert，但是用户没点，JS那边触发了 closeWebView hybrid接口，导致alert的complete回调没调，导致崩溃。

   c. 还有就是非http/https的url，需要手动调用NSURLApplication去打开，包括mail://、tel://这些。

   d. 视频非全屏播放，iOS8、9、10上配置都不一样

   e. <a>标签无法跳转

#### 取得的成果

1. 梳理并统一了原来项目里面各自实现的Web容器，提供了一个通用的Web容器组件，每个业务可以按照自己需求，实现自己的Hybrid API。
2. 整套方案工作稳定，没有出现严重的线上故障，当然在做的工程中，兼容性问题还是有的，当时做了一个非常复杂的配置系统，去灰度这套方案。比如URL白名单、黑名单、设备系统版本、App版本、整体开关等。

### 2、Web容器优化

#### 1. 白屏检测

##### 方案背景

⽩白屏检测可⽤用于主动发现并上报iOS客户端⽤用户在使⽤用WebView时可能遇到的⽩白屏问题。与传统的等待测试或者⽤用户反馈问题相⽐比，通过⽩白屏检测机制，让我们在对Web服务的问题处理理上变的更更加主 动。它能够让我们尽早的发现并排查解决Web服务相关内容可能存在的潜在问题，进⽽而提⾼高服务的可靠性和⽤用户体验。

#####  技术方案

在Web⻚页⾯面开始加载/加载完成/加载失败之后对整个⻚页⾯面进⾏行行截屏，然后通过 ⽩白屏检测算法对截屏所得图像进⾏行行处理理，根据算法所得结果进⾏行行判定⻚页⾯面是否白屏，如果认定为⽩屏，则将图⽚片上传到NOS保存。

通过Hook，UIView和WKWebView的setDelegate方法和loadRequest方法，监听web容器开始加载/加载完成/加载失败。

其中loadRequest是为了检查，一定延迟后，截屏看页面是否是白屏

didFailLoad、didFinishLoad、failProvisionNavigation这块，主要靠hook setDelegate方法，然后创建proxyDelegate对象，通过消息转发来捕捉截屏。

这边timer都需要用GCD source timer，因为都是在子线程里面。

截屏这块iOS 10以上用的是UIGraphicsImageRender、iOS 10以下用的是CoreGraphics框架。

白屏检测的算法是用的CoreImage框架的CIDetector，这个东西可以提取图片里面人脸、矩形、⽂字数量，只要任意元素大于0，我们就认为是非白屏，否则判定为白屏。

整个项目里面也有一些检测机制：比如检测延时机制、疲劳值机制、URL白名单机制。

最后检测结果哨兵+NOS上报。

我们同时对HOOK的delegate proxy做了伪装，重写了proxy的`isEqual:`、`hash`、`superclass`、`class`、`isKindOf:`、`isMemberOf:`、conformsToProtocol等方法，同时`isProxy`方法返回YES。

##### 取得结果

请求重试(-1001)、网络连接中断(-1005)、已断开与互联⽹网的连接(-1009)占了70%左右；

无法显示URL，不支持URL，占比20%左右，这类错误是由于客户端尝试去通过 Scheme打开⾮白名单内的的URL，被App拦截；

DNS查询失败8%左右，SSL握手失败3%左右；

帮助我们发现了有些被误拦截的Scheme跳出。

#### 2. H5资源预加载

##### 方案背景

H5业务数据加载耗时长，平均数据加载耗时400~500ms左右。通过预加载机制，能够有效缩短该时间。

H5页面加载过程，首先是准备Web容器，web容器打开，还是加载url，那么web容器会先去解析DNS，建立TCP连接，下载HTML资源，然后JS加载、解析，然后开始执行js业务逻辑接口路，拿到数据后开始做首屏渲染，渲染结束，页面出现。

在这一段过程中，从解析DNS开始，Native这边基本就是干等着。

这个主要业务场景是帮助中心相关页面。

##### 技术方案

在Web容器准备好之后，开始loadRequest的同时，Native这边按照加载url，映射对应的H5业务接口，然后使用NSURLSession同时发起这些请求，然后将结果，按照url+API名字做key，写入一个全局的hashMap中。H5那边在HTML和JS加载完成之后，通过JSBridge调用Native这里的preload API，按照url+API的hash来取结果，

如果Native这里请求完成了，那么就返回数据，如果还没有结果，那么就返回特定错误码，让H5走兜底策略，自己再去做这个AJAX请求。拿到数据后，在做首屏渲染。

##### 遇到的问题

JSBridge协议生效太晚，数据无法交换，这个问题主要发生在安卓上，解决版本很简单，就让前端自己注入JSBridge；

数据污染问题，H5页面数据不更新，解决办法很简单，每个结果只能用一次，取过就删，然后退出web容器也清理；

##### 取得结果

数据获取成功率，96%左右，缩短了首页白屏时间400~500ms左右。

#### 3. 动态下发JS代码执行

屏蔽有些第三方页面内跳出下载App的行为和Banner。

通过配置接口下发需要注入执行的js代码，在web容器初始化的时候，按照url过滤，加入UserController中去，等页面加载完成之后执行。

### 3、Automic UI test

##### 背景

减少回归人力成本，保证支付SDK交付质量。

##### 方案设计

总体思路，手动添加accessIdentifier，然后按照identifier记录时间轴。

同时在开始录制的时候，配置好需要做网络请求录制的URL列表白名单，并把配置信息告诉自定义的EYENetworkProtocol对象，EYENetworkerProtocol对象，是一个自定义注册的URLProtocol。它其实一直是在拦截网络请求的，在`canInitWithRequest:`方法里面，它会去度配置，看当前是不是配置了录制或者播放动作，然后看是不是在白名单里，如果在白名单里，返回YES，进入拦截流程，如果不是返回NO，直接放行。

如果拦截的请求，则在`initWithRequest:cachedResponse:client:`方法内返回，自定义的EYENetworkProtocol实例，同时需要需要按照播放/录制生成一个对应的Handler对象。`EYENetworkProtocol`里面实现了`startLoading`和`stopLoading`方法，系统调用`startLoading`的时候，执行handler的`handleStartLoadingWithProtocol:`方法。

录制handler里面，就把protocol里面的request拿出来，使用NSURLSession去发请求，同时有个`EYENetworkRecorder`单例开始记录网络请求，`EYENetworkRecorder`里面就是一个串行队列，负责记录请求核心的几个阶段，比如`willStart(task resume)`、`willPerformHTTPRedirection:`、`didComplete`、`didReceiveResponse`、`didReceiveData:`，同时还要把结果继续通过protocol.client继续传出去，让业务录制不受影响。

这里面还有一个细节就是，实现了一个NSURLSessionTask子类，因为所有网络请求其实公用了一个NSURLSession实例，这个实例在init的时候只能指定一个delegate，就是统一的SessionRelay对象，然后SessionRelay对象实现了所有NSURLSessionTaskDelegate和NSURLSessionDataTaskDelegate，同时Relay里面有个HashMap，key是NSURLTaskIdentifier，一个是真正的EYEURLSessionRelayTask。然后收到task delegate的时候，通过task.identifier找到EYEURLSessionRelayTask，然后看它能不能应答delegate方法，如果可以转发给它，如果不行，则走通用处理逻辑。

最后stopRecord的时候，先遍历所有的recorderModel，转成playableModel，然后做序列化，再转成base64字符串，写入一个plist里面。在把整个plist传到Ironman。

播放recorder里面，就把整个plist下面来，然后调用`playNetoworkForHost:file:`接口，同样的先生成`EYENetworkHookerConfig`对象，更新到EYENetworkHookerProtocol里面的config静态变量里面去。然后就是走NSURLProtocol流程，比如`initWithRequest:cachedResponse:client:`，这里的判断依据是是否在白名单里，是否在playableModel列表里，playableModel判断是根据scheme+url+path。

然后就是生成`EYENetworkProtocol`对象，同时生成`playableHandler`实例，然后就是playHandler内部逻辑触发。这部分逻辑参考了OHHTTPStub。这里核心就1点，如何模拟类似实际的网络请求的播放，比如原网络请求2秒后报错了，或者原网络请求总耗时是4秒，那么就要模拟出4秒的感觉。

##### 方案难点

1. config的存取，存使用了`dispatch_barrier_async`，读取使用了`dispatch_barrier_sync`，因为提高并发读取的效率，并且外层接口希望实现同步读取的效果。
2. 消息录制和播放，都必须创建runloop，这是之前没有注意到的；
3. 请求播放的过程中，使用了分段定时传输的方式，每0.25秒传一点，先用 总responseData / 请求总耗时 * 0.25，计算出每0.25秒的数据量；
4. 整体的设计和实现，还是需要比较小心，多线程问题这些都是很容易犯错的；

##### 取得的成果

和团队成员一起成功实现了UI自动化测试，帮助降低了测试压力，提高了SDK可靠性；

### 4、Networking slot

##### 背景

解决网络请求监控数据空白的痛点，帮助定位用户网络请求问题，为网络请求性能优化提供数据支撑；

##### 方案

要实现Native/NSURLSession的网络请求拦截，有两种思路，一种是使用NSURLProtocol，一种是通过Hook网络请求发起的一系列方法。比如NSURLSessionTask的`resume`、`cancel`方法，还有`NSURLSession`的`setNavigationDelegate:`方法，delegate通过proxy方式实现，然后HOOK中间关键函数比如`willPerformHTTPRedirection:`、`completeWithError:`、`sendRequestBodyData:`、`collectionMetrics`、`receviceResponseHead`、`didReceiveData`、`didBecomeDownloadTask:`，以及downloadTask的下载完成和进度两个代理方法。然后task resume的时候，记做请求开始，ObserverManager里面一个hash表，有一个并行队列，hash表的key是task.identifier，然后值为NetworkingPerformanceModel，里面属性就是一些网络请求过程中的时间节点。然后当网络请求结束的时候，把这个model在丢给哨兵哨兵DataWriter，这里就可以用到条件锁了。

##### 难点

1. `task resume`方法的Hook，因为NSURLSessionTask是类簇，在iOS10~13，真正实现的是`__NSCFURLSessionTask`上，在iOS 9和iOS 14上，真正实现是在`NSURLSessionTask`上，在iOS 8以下实现是在`__NSCFLocalSessionTask`上，需要做好兼容工作。AFNetworking里面，也有这部分兼容，AFNetworking的做法是，创建一个临时的NSURLSessionDataTask对象，然后开始循环遍历，每次循环里面，取出当前对象和它父类的`resume`对应的IMP，如果一致，说明子类没实现，这个方法实现是在父类里面，那么子类变成父类，继续遍历，直到找到当前类和父类不一样，并且当前类和AF的resume类IMP不一致。
2. 同时该框架还支持了Web容器的首屏时间统计，这个是通过window.performance.timing去做的，这个是iOS和android通用的。后续打算在iOS 11上使用WKURLSchemeHandler去做，这个还在技术调研中，因为还需要安卓那边配合。

##### 成果

成功解决了网络请求监控数据空白的痛点

### 5、Ironman

##### 背景

支付SDK打包发布流程太长，维护工作耗费人力。我的说的打包是指pod lib package，发布是指pod repo push。我们提供给商户的SDK是闭源的，所以需要先用pod lib package打成framework，再统一放到一个发布工程里面进行pod repo push。

##### 技术栈

Node + Koa + Vue + MongoDB + Mongose + shell

##### 主要架构

Router层接收请求，做简单的请求参数校验，然后调用Service层做真正的业务。由于要实现SDK组件化打包，这边设计了一个任务队列。所有SDK打包、发布任务、还有其他的跑UI自动化测试、测试ipa打包这些都后在Service层转成一个OperationGroup，OperationGroup在初始化函数里面会按照实际关联生成对应的ChildOperation，然后给前端返回这个OperationGroup信息。然后会把整个OperationGroup对象push到一个OperationQueue中。整个OperationQueue驱动很简单，就是每次有人调用appendOperation，他就开始走while，每次拿出队列的第一个OperationGroup，先看它有没有被标记为canceled，没标记就拿出它的childOperations，开始遍历，childOperations用的是队列，只要队列next不为nil，会一直走group里面的循环。childOperation又会根据类型，通过worker工厂，转成实际类型的worker。基类work里面定义一些基础的数据库查询和更新操作。然后子类一般需要重写register方法，willStart和didStart方法。

willStart方法一般用于从数据库查询必要的基础参数，然后在didStart方法里面，拿那些参数去调用脚本Adapter，然后Adapter里面会去找出真正的脚本执行，执行之后返回给didStart，然后didStart把结果返回。然后系统调用didFinish更新结果。

整个OperationGroup有5个阶段，从pending、working、canceled、success、fail。

Worker有个基类，定义了任务真正执行的一些函数，比如workWillStart、didStart、willFinish、didFinish、didCancel。

这里要讲一下的是为什么childOperation用的是链表，而不是数组，主要是因为某个子模块打包失败了，然后继续在打包后面的模块，我们可以在前端直接重启这个失败的子模块任务，如果用数组，因为循环的时候已经确定数组大小，那么后面其实不能遍历到这个模块的，用链表就可以解决这个问题。

整个这样的架构就比较容易扩展，增加新的任务类型，比如增加一个备份数据库的接口，那么只要实现一个MaintanceDBWork，然后在里面实现register、willStart、didStart方法，同时在ShellAdapter里面提供一个下备份书库的脚本shell路径，就OK了。

##### 遇到的问题

1. 学习新知识，比如nodejs、mongose使用；
2. export、require、import这些变态的语法；
3. js的灵活性，由于没有静态检查，很容易出问题；

##### 成果/解决的问题

1. 支付SDK打包发布时间从原来的6小时，缩减到点一下，后面只要注意邮件就好了，大大的释放了人力资源；
2. 由于有这个平台，也支持了历史版本管理，已经发布的SDK版本再这上面一目了然；
3. 支持迭代发布，比如一个版本只改了一个小模块，那么这个版本我重新勾一下这个小模块，重新打包发布下就OK了；

##### 其他

Iornman还有一个比较好玩的功能是自动重启接口，这个功能刚开始我是想直接用跑shell(npm库shelljs)，用ps+sed+awk找出node服务的pid，kill掉，但是试了一下好像不行，我怀疑是shell执行环境也跟着node进程被杀消失了？(这个我当时也不确定)，因为之前看node简介，又看到childProcess这个东西，就去查了一下相关用法，发现有fork这个功能，然后就用先用child_process.spwan执行`ps`、`sed`、`awk`，然后相互用pipe连接起来，因为每次只能执行一个脚本，然后就可以拿到pid，拿到pid后，用child_process.fork创建子进程，然后用这个fork出来的进程去执行一个reboot的脚本，脚本里面先杀掉主进程。因为fork的时候设置detached是ture，这样主进程被杀子进程也没事。然后再执行拉代码，npm等这些命令。这样就实现了重启服务器接口，该接口指定的参数里面有对应的代码分支。

这个功能后面我又做了一点优化，配合gitlab-runner，我在打包机上起了一个gitlab-runner，然后ironman代码库配置了gitlab-runner的YAML，同时写了一个脚本，能够在ironman代码分支提交之后，按照commit信息，如果最后有[reboot]，就向gitlab-runner触发的脚本，实现自动重启服务器，点一下都不用点了。

### 6、Device Fingerprint

##### 背景

由于涉及用于资金安全，原来用的是行研的设备指纹方案，但是他们设备指纹方案有时候会丢，准确率还有提升空间，所有风控希望我们能实现一套自己的设备指纹。

##### 方案

通过采集用户手机的设备名称、设备型号、IDFA(有就取没有就自己生成)、屏幕分辨率、屏蔽缩放比例、上一个UUID这些数据，加密发送给风控，风控再对每个项目进行比较，如果有不相同的，则会增加不同指数分，一旦不同指数分超过2分，就判定当前设备不是同一设备。

应用第一次启动的时候，先去内存缓存中度这些信息，没有就去采集以上数据(除了上一个UUID)，然后同步去读keychain缓存。如果没有keychain缓存，则把数据加密，同时更新的到chainkey，同时把明文信息更新到内存缓存。如果keychain查到了，则先解密，然后比对个数据项，如果存在改动，则重新加密更新到keychain，如果没有变更，则直接更新到内存缓存。然后返回给外层，外层再获取当前时间戳，升级随机生成AES秘钥，对称加密这些数据，然后用AES秘钥用App内置的公钥加密，传给后端。这边RSA加密结果缓存，AES key缓存。

如果内存缓存中命中这些数据，那么直接返回给加密层，加密层再加密传给后端。

这样之后请求中的风控信息里面，只要用AES加密一下+时间戳的数据，传给后端就好了。

##### 遇到的问题

RSA加密失败兜底问题，偶现，大概万分之二，增加重试机制和兜底机制，预置的AES key + 内置的RSA加密好的密文，这样只要做一次AES加密就好了。

##### 成果

指纹设备稳定率比行研方案更稳定，覆盖率基本达到了99.99%，同时也提供了方案切换的能力。

### 7、Flutter dynamic framework

##### 背景

解决Flutter不能热更新的痛点，同时也做为技术难点去尝试攻克一下。

##### 方案设计

1. 首先确定整体方案思路，整体思路是参考了MXFlutter，通过JS的动态性，动态去加载js包和json描述文件。
2. 和MXFlutter不一样的地方是，它是在JS侧动态的生成页面描述的JSON，我们则是静态编译的，这样就提高了一点性能，减少了页面进入时候的运算量；
3. 通过Flutter的StatefulWidget构建widgetTree；
4. Flutter侧，每个页面有一个pageId，对应一个page，JS侧按照这个treeID，也有一个page对象，page对象里面主要是挂载了一些事件响应方法，这样就实现了点击事件的响应；
5. 然后这个页面是通过数据驱动的方式去实现的，比如一个页面的是否隐藏，是通过属性的isHidden决定的；

我主要解决了整个流程中的2个难点，一个是写的widget模板代码转成JSON，一个是模板类生成。



整体流程：

1. 用户点击某个图片，准备启动小程序模块A，首先启动JS执行环境和Flutter engine。
2. 然后调用js引擎的lanch方法，传入小程序URL，小程序URL格式为"minigame://"开头，拿到这个之后，我们会去documents下面找`minigame`文件夹，然后里面应该有一个main.js。
3. 然后执行该js，该js里面入口函数，主要准备一下唤起上下文，全局容器的生成。准备好之后会通过Native通知Dart层，准备启动App，Dart层收到后，则找Native要模板JSON文件路径，Native再把模板JSON路径返回给Dart，Dart拿这些数据，构建出空的页面骨架。
4. 然后再通知JS层，调用syncState，把对应的骨架pageID什么传过来，还有表达式映射信息；
5. 然后JS这边同步好状态之后，发送网络请求，开始拉取页面数据，拉取页面数据之后，把数据更新到对应属性上，然后调用setData方法把数据发送给Dart侧，这个数据里面包含了TreeId、PageId，p及值；
6. Dart侧收到setData调用后，根据PageId和p，遍历整个tree，找到对应节点，更新其p值，然后调用系统的setState方法，重绘页面；

##### Widget转JSON整体逻辑

1. 主要是要想好Widget和JSON的映射关系，Widget这边有字面量(true、false、null)、字符串、数字、数组、字典、对象和枚举这几种类型，映射到JSON这边有字面量、字符串、数字、数组、对象，那比如说我要把flutter的对象映射成JSON，就需要在json里面的对象，就需要增加一个自定义属性cls；比如flutter里面的枚举，是xxx.case，同时里面还支持匿名的属性，那么转换之后的JSON里面我们给他增加了`cmd`字段，对应.case值，还有匿名属性 ，自动增加，通过`p1`，`p2`这种方式自动扩展。
2. 整体解析就是一个向下递归的过程；

##### 模板代码生成

所有的Dart对象，都要在Dart侧提供一个对应的包装对象，比如Text对象，我们这边要包装成NEJFTextNode，然后在该函数里面实现buildWidget方法，然年后再构造出真正的Text对象，为啥要这么搞呢，因为真正构造出这个Text对象所需要的属性，其实都是在上面将的PageTree上，上面挂的是一个抽象的数据结构，你可以认为是一个Map，然后通过该perperty key做映射，然后在这个`valueForProperty`方法里面，去递归的构造真正对应的属性。拿到属性之后，可能还要按照原值调用我们专门的`valueToBool`、`valueToInt`这些方法。

同时想enum这种，还有快捷构造函数，其实是包含两个分支的，这种都要重写buildWidget方法。

主要通过一个靠一个`analysis_server_lib`库，来实现，通过该库来爬取所有类的构造函数，该库的作者是Dart语言的作者，这个库用于对接Dart‘s analysis server API，真正的服务端代码是在`/usr/local/Cellar/dart/2.8.1/libexec/bin/snapshots/analysis_server.dart.snapshot`下面。

这个下面的才是真正编译后端的代码，然后analysis_server_lib通过Dart预发实现了那些接口，看以在idea java版本的插件下面看到类似的定义，snapshot提供真正的服务。

类似我们IDE，你写代码的时候，其实后面都有一个编译后端跑着。

然后思路就很清晰了，搞一个临时项目，然后丢给analysis_server，订阅它的`ANALYZED_FILES`事件，就可以自动获取所有依赖库，然后遍历这些依赖文件，然后注册onFlutterOutline事件，它每解析好一个文件的结构，就会丢到你的注册函数里面，然后就可以拿到FlutterOutlineEvent结构体，然后遍历子节点就能找到里面的所有构造函数。

查出构造函数之后，就需要在把构造行数的名字，填充到临时项目的一个模板文件里面，然后就能拿Hover事件，他就会给你返回真正的构造函数了。

##### 成果

上线后iOS帧数保持在54~60帧左右，Android则基本在50~55左右，低端机上还是比较吃力的

内存占用这块，首日进入有一个较大的内存占用增加，大约在60M左右，相比混合开发(Flutter混合开发每次打开页面占用内存大概增加在40M左右)

然后之后再进出大概内存升降在10MB左右；

##### 问题

1. 性能上还是存在一定的优化空间；
2. 开发比较调试都是比较痛苦的一件事，开发上由于自定义语法，没有插件支持，会报错，用JS写逻辑，用Dart写页面，切来切去，不适合大规模开发，团队内就我们几个搞这个框架的会写，其他人都不会写；
3. 每次Flutter版本更新都要做大量适配工作，同时还依赖的第三方框架，这些框架都需要一并升级；
4. 预发支持度不够；

### 8、Flutter卡顿检测

##### 背景

解决Flutter Devtools不能在线上环境运行的痛点，为线上App性能提供数据支撑；

##### 原理

1. FPS检测原理

通过注册window.onReportTimings可以定期获取到帧渲染数据，Flutter v1.12.13上改成了SchedulerBinding.instance.addTimingsCallback注册；

计算FPS的公式很简单 FPS = 实际渲染帧数 / 理论可渲染帧数 * 每秒最大帧数

上面讲到注册block之后，会定期返回一个FrameTiming列表，拿到这个列表遍历就能计算帧数。

遍历拿出每个FrameTiming，然后 用它的总耗时 / 每帧耗时 + 1，就是实际占用帧数；

需要注意的是，这里面有一个帧组的概念，看FlutterIntellijIDEA插件源码可以知道，如果连续两个FrameTiming之间的开始时间和结束时间值超过 2 * 16ms，就认为这两帧是属于两个不同分组的。一旦检测到一个帧组结束，就需要输出一个FPS值了。

像iOS中基本都是用CADisplayLink去计算FPS，然后两个帧组之间的间隔大家貌似都用的是1秒，当前帧时间 - 上一帧时间如果大于1秒，就输出FPS，不然继续累加。

然后这个FrameTiming里面的总耗时是由两个时间组成的，一个是 buildDuration、一个是 rasterDuration，按照官方文档的注释，一个是GPU等待渲染内容，那其实第一个build时间，就是CPU处理时长，第二个raster时间，就是GPU处理时长。

按照iOS的经验，第一个时长过长，往往是视图创建、布局计算、图片解码、文本绘制这些耗时过长造成的，CPU耗时过长，往往会导致卡顿，用户操作无响应；

第二个时间过长，往往是变换、合成、渲染时长过长导致的，这个看起来就是页面跳动，但是操作还是可以及时响应。

2. UI线程卡顿检测原理

Flutter的主线程是一个EventLoop模型，其实和iOS的runloop模型几乎一样，它在loop主要处理两种时间，一种是source事件、一种是timer，通过在主线程增加一个定时器，那么每次触发定时器的时候，和前一次的时间戳比较，就可以发现超过1秒，就认为触发卡顿了。

##### 效果

能上报数据，我们通过在页面push和pop的时候，自己维护一个identifier栈，能够知道发生卡顿时，当前的页面是哪个，但是不知道具体是哪里卡顿了，还需要人工排查，因为如果触发卡顿的时候去Dump堆栈，其实拿到的是卡顿检测自己的堆栈。

在线上的时候，就发现吐槽页面，有卡顿，后面排查发现是点击上传图片，图片选择之后传输有点耗时，原来是直接从Native通过Method channel把base64的图片数据传到Flutter这里，后面改成了传地址，然后Flutter侧自己按照返回的地址，去读图片。

### 9、商户接入环境扫描

##### 业务背景

商户接入支付SDK某些配置忘记配置，或者编译所使用XCode版本未经过我们测试覆盖。XCode的问题之前App遇到过一次，使用imageAsset导致iOS 9上用户大量崩溃，iOS 12直接向Cell上添加内容，如果没有调用过cell.contentView，导致按钮什么等被contetView覆盖。

##### 实现方案

通过扫描商户App内的info.plist文件，读取里面的各种信息。主要包括以下配置项：XCode版本、最小系统版本、BundleID白名单、URLQuerySchemes、URLScheme、隐私配置项。

XCode最小版本主要是提示商户，如果商户XCode版本比我们高，那么可能存在兼容性问题，需要我们这边测试介入再次测试。

其中URLQuerySchemes主要看商户接没接特定模块，比如农行掌银支付的，需要跳出到农行掌银，就需要先查询用户手机装了没，就要赔这个scheme。

隐私项主要是用户摄像头配置，这个基本老商户都会配置，可能新商户会忘记配置。

##### 遇到的问题

希望在商户Debug下运行和提示，但是提供给商户的是已经编译好的静态库，没法用DEBUG宏，通过P_TRACED标记，来判断是否在Debug环境下。

##### 取得结果

这个功能刚上线，接的商户并不对，还内有特别多的数据。

### 10、支付SDK组件化架构

SDK本质上的架构方式和protocol组件化思路比较接近，我们通过一个中心的话的BusinessStack来管理所有的子业务，比如支付、添卡、充值、人脸等等这些业务模块，每个业务模块都实现了`BusinessProtocol`这个协议，该协议定义了几个行为，比如`startBusinessWithTaskInfo:`、`closeBusinessWithError:results`、`receiveRiskChallengeWithError:data:`这3个基本接口，以及一个`NEPBusinessTaskInfo`这个一个基础参数，它是启动每一个业务的上线文/参数对象。

然后比如商户商户需要使用的支付接口，是通过`NEPBusinessTaskInfo`的分类定义的，通过该接口会生成一个taskInfo实例，然后再用`BusinessStack`推一个业务。

BusinessStack业务栈推业务的核心逻辑如下，按照taskInfo里面的businessIdentifier生成一个对应的Business实例，这个Business实例就是我前面说的不同的子业务，但是都遵循了`businessProtocol`，然后把它添加到把它添加到BusinessStack的栈容器顶部，同时调用`startBusiness`方法。

从页面层次上来说，这个比较容易理解，首次推出一个business，我们会生成一个自己的window覆盖在商户window上面，然后rootVC就是一个NavigationController，同时这个Navigation的rootVC是一个fakeVC，最底层业务的fromVC就是这个fakeVC，因为首个页面出现也想要有弹出动画。我们的弹窗目前主要有2中，一种是alert类的，一种是全屏的。

navigation的push动画很简单，就是实现了自定义的`naviagationController:animationControllerForOperation:fromViewController:toViewController:`方法，然后实现了几个`UIViewControllerAnimatedTransitioning`动画。

### 11、iOS常见崩溃

##### 为何发生崩溃

- CPU无法执行的代码，比如除0，比如nil强制拆包；
- 被操作系统强杀，终止那些卡顿时间过程，加载时间过程的应用，比如启动时间过长，导致watchdog强杀，还有内存耗尽、非法的应用签名
- 编程语言为了防止错误而触发的崩溃，比如`NSArray`或`Swift.Array`越界；
- 断言导致的崩溃；
- 因为内存访问权限导致的崩溃；

##### 如果获取崩溃日志

- 通过XCode内置的originize里面的crash列表；
- 借助Firebase、Bugly这些第三方框架捕获崩溃；
- 从测试设备上导出崩溃日志；

##### 常见的崩溃

1. 崩溃类型为`EXC_BAD_ACCESS(SIGSEGV)`，这种一般是对只读的内存地址进行写操作，还有是访问不存在的内存地址；

2. 编程语言异常，比如数组越界，`EXC_CRASH(SIGABRT)`

3. WatchDog强杀，`EXC_CRASH(SIGKILL)`

4. 对象重复释放

5. 内存地址读写异常，常见的错误是`EXC_BAD_ACCESS(SIGSEGV)`，这个比价有经验，常见的异常是读取一个`KERN_INVAILD_ADDRESS`，然后下面会列出虚拟内存布局

   比如Region Type、START_END、PRT、REGION DETAIL

   之前在开发中我们遇到的异常是，报了一个这错误，但是我看到`KERN_INVAILD_ADDRESS`是有效的，落在有效的VM区间内，但是发现该地址段的权限是`rwx/r--`，后面排查后发现是我们项目中启用了DataProtection选项，并且权限配置成了Complete，用户锁屏后，行研的七鱼SDK还在写数据，但是这时候已经没有写的权限了，所以导致了应用崩溃；

6. 动态库链接异常，常见错误是`EXC_CRASH(SIGABRT)`

##### 如何符号化

1. symbolicatecrash
2. atos

如果不能符号号，怎么解决问题？

可以尝试通过lldb调式，反汇编，disassemble命令，拿到对应的汇编代码，进行分析，这个就比较累了。

##### 崩溃日志分析建议

- 不要只关注崩溃发生的那一行，多查看一下和崩溃相关的代码，经常会出现崩溃代码不是真正导致bug的崩溃；
- 查看所有调用栈，不要只关注崩溃所在的线程和调用栈，非崩溃线程调用栈可以帮助我们查看崩溃时应用所处的状态
- 使用Address Sanitizer或者Zombies

##### 实际解决的问题

1. 多线程定位模块崩溃；
2. 上面讲的七鱼SDK读写崩溃；
3. GCD Group崩溃；

##### Zombine实现原理

1. Hook系统的dealloc方法，当正常调用dealloc方法的时候，如果引用计数变成了0，就生成一个对应的Zombine对象，让原对象的isa指向这个动态生成的Zombine对象；
2. 在对象未被释放的情况下，销毁对象变量和关联对象；
3. 然后再次调用已被释放对象的方法时，其实会调用到Zombine对象里面，然后Zombine对象会响应该调用，并打印调用栈和类名；

## 项目方案

### 1、H5收银台唤起支付App方案

##### 业务背景

藏宝阁H5端使用的是网易支付H5收银台，希望把这部分用户能唤起支付App，已提高支付成功率

##### 技术方案

1. 经过调研，通用链接唤起的概率比scheme大，通用链接除了QQ浏览器，微信低版本浏览器，还有夸克浏览器，其他浏览器经测试均能跳出唤起支付App。像百度、熬游这些浏览器均拦截了scheme跳出。
2. H5端通过尝试唤起后，会向后台发一个请求，通知后端已尝试唤起，App这边如果唤起了，则会向后端发个请求，告知已经发起；H5端轮训到已唤起后，停止轮训；
3. 唤起的url里面有一个ticket，保证该url只能唤起一次，防止钓鱼；
4. App这边需要对一些检查，比如唤起url的sign值是否正确，时间戳的时间是否超过5分钟，有没有多出额外的参数，设备是否越狱等，并提交给风控；
5. App这边需要处理订单和账号不一致问题；
6. App这边支付完成，需要调会用户浏览器，如果是普通浏览器，我们H5那边通过UA有个映射关系，url参数里面会告诉我们这个浏览器的昵称，我们这边维护着一张昵称对应回调scheme的表，后面支付完成，拼接生成对应浏览器的scheme，然后再回调过去，这边safari的表现和其他浏览器表现不太一样，它自动重启一个tab页，所以要做特殊处理，方式H5那边再次唤起支付App，进入死循环。

##### 效果

综合下来H5页面跳转到支付App支付，最终提升支付成功率在3.5%左右；

### 2、切换账号支付方案

##### 背景

SDK允许用户切换账号进行付款

##### 方案

1. 支付流程中嵌入切换账号模块，如果切换成功后，下次唤起自动切换成上次成功付款的账号B；
2. 如果静默切换失败，则还是使用当前账号进行支付；
3. 和藏宝阁URS账号登录体系可能会冲突，比如切换账号之后，需要清理所有cookie，注入新账号的NTES Cookie；

### 3、账号合规通道方案

##### 背景

合规部门要求藏宝阁配合，对不合规账号的提现、下单交易等流程进行拦截，因为是藏宝阁配合，所以方案要设计的足够通用，不能只考虑眼前问题，同时还要 满足藏宝阁侧改动尽可能的小。

##### 方案

1. 后端提供一个账号是否合规的API，藏宝阁服务端在请求支付Server这边先请求这个接口，后把结果返回给藏宝阁App，藏宝阁App侧收到数据，如果里面isLegal是false，则弹窗拦截，弹窗两个按钮，一个取消，一个确定更改。
2. 点确定更改，把服务端返回的数据，传给支付SDK，SDK这边通过解析该内容，判断如果进行下一步业务；
3. 由于SDK这边已经有很多的小的业务模块，同时也有丰富的hybrid接口，我们这边会根据里面的内容做出对应的业务选择；
4. 比如是一个url，则打开一个H5中间页，中间页可以动态发布，动态更改，同时也可以调用Hybrid接口；
5. 为了保证体验，这边也支持直接跳过H5页面，根据入参里面的biz字段，如果这边已经有注册的biz，则直接唤起对应的Native业务；
6. 整个流程做完，返回结果给藏宝阁，藏宝阁只需关注是否成功，成功则放开拦截，不然继续拦截。

##### 成果

这样的设计就保证了，这次合规要求验证人脸，下次合规要求添加银行卡，或者验证预留手机号，这些业务都能快速的补全和触发，同时H5中间页提供了灵活性，有的业务哪怕没有Native能力，或者Hybrid接口，都能在H5上面承载，H5做完业务可以通过通用的bizResult业务接口告诉SDK结果，SDK再返回给商户。

## OpenSource Reading

我读过的开源框架库AFNetworking、SDWebImage、Aspect、YYCache、YYModel、JPVideoPlayer、FMDB、OHHTTPStub。

### SDWebImage v5.10.3版本

SDWebImage就比较复杂了。WebImage主要包括以下几块：各种View的Category，用于提供快捷访问入口。图片缓存模块ImageCache，核心协调模块ImageManager，图片Loader模块，图片下载模块，图片Coder，动图相关模块。

SDWebImageManager类里面有几个核心属性，一个是实现了`SDImageCache`的cache，一个是实现了`SDImageLoader`的loader，另外还有什么`SDImageTransformer`用来做变形的等。

我们调用`UIImageView`的setImageXXX方法，其实会调用`UIView`的internalSetImageXXX方法。SDWebView使用了大量的关联对象去存储信息，比如OperationKey，operationDictionary这些等等。

在UIView的`internalSetImage`方法里面，先会cancel当前的opertaion。这个operation其实是`SDWebImageCombinedOperation`对象，但是这个和NSOperation毛关系没有，它里面持有了两个Operation对象，一个是`cacheOperation`一个是`loaderOperation`。`SDWebImageManager`里面有一个`runningOperations`数组，管理着这些combinedOperation。

这个cacheOperation是一个NSOperation对象，但是这个对象其实也没啥用，就是在真正做Disk查询的Block里面，先判断下该operation是否被标记为isCancel。

这个loaderOperation是一个`SDWebImageDownloadToken`对象，真正是在在cache未命中，或者配置了不查cache后生成的，然后对应的`combinedOperation`里面的loaderOperation是调用`SDImageLoader`的`requestImageWithURL:options:context:progress:completed`生成的。其实本质是在`SDWebImageDownloader`内的`downloadImageWithURL:options:context:progress:completed:`生成的。

这个`DownloaderToken`里面持有一个`WebImageDownloaderOperation`，然后这个`DownloaderOperation`里面持有下的的NSURLRequest对象。然后这个`SDWebImageDownloader`里面持有一个`downloadQueue`，同时还持有一个`NSURLSession`实例。同时在生成`WebImageDownloaderOperation`有一个NSURLSession实例的弱引用，同时在在downloadQueue里面触发这个operation的时候，它会发起真正的网络请求。

### OHHTTPStub

简单

### AFNetworking

这个就比较简单了，AFNetworking主要分几块，一块是核心的AFURLSessionManager类,还有包装后的的AFHTTPSessionManager类。还有网络情况探测的`AFNetworkReachabilityManager`类，同时还有包装了HTTPS安全配置的`AFSecurityPolicy`类，另外还有request和response的序列化类，序列化类的主要工作时根据context-type，生成合适的NSURLRequest对象。比如multiform data类型的request，json类型的request，plist类型的request。response也是差不多。

然后核心的URLSessionManager类里面有个一个hashMap，保存着每个NSURLSessionTask的taskIdentifier为key，`AFURLSessionManagerTaskDelegate`实例为value。

这个TaskDelegate其实是一个包装对象，解决NSURLSessionManager的delegate和多个task之间一对多的问题。然后这个TaskDelegate里面实现了didReciveData，completeWithError这些网络状态改变的delegate方法，同时delegate里面还持有了progress、complete、upload、download等block，用于在对应状态调用该block，返回结果给外层，同时还有一个NSMutbleData对象来接受数据。

这边有个小细节，对于`NSURLSessionTask`的`resume`和`cancel`方法的hook可以讲一下。

### YYModel

简单

### YYKit

简单

## Flutter

### 1、 Flutter的线程模型

Flutter包括4个runner，分别为UI Runner、GPU Runner、IO Runner、Platform Runner4个。

其中Platform runner类似于iOS中的主线程，但是阻塞Platform Runner并不会导致Flutter应用卡顿。

UI Task Runner用来执行Dart root isolate的代码，一次渲染大概流程如下：

1. Root isolate通知Flutter Engine有帧要渲染，Flutter Engine通知平台层，需要在下一个vsync的时候得到通知。
2. 平台等待下一个vsync，对创建的对象和widgets进行layout并生成一个layer tree，这个tree提交给Flutter Engine。当前阶段并没有进行任何光栅化，这个步骤仅是生成了对需要绘制内容的描述。
3. 创建或更新tree，这个tree包含了用于屏幕上显示widgets的语义化信息。

UI Task Runner还负责处理Timers、Native Plugins的消息响应、Microtasks和异步IO，因此该线程过载会导致卡顿掉帧。

GPU Task Runner，用于将Layer Tree提供的描述信息，转化为GPU指令。同时也负责配置管理每一帧绘制所需要的GPU资源，这包括平台Framebuffer创建，Surface生命周期的管理，保证Texture和Buffers在绘制的时候是可用的。

IO Task Runner，主要工程是从图片存储(磁盘)中读取压缩的图片格式，将图片数据进行处理，为GPU渲染做好准备。该Runner和GPU Runner存在一个共享的Context。

##### iOS平台上，每一个engine创建都会新建一个UI、GPU、IO Runner，但是Platform Runner是共用的。

### 2、渲染引擎分析

Flutter渲染流水线模型大致如下:

Widget Tree -> Element Tree -> RenderObject Tree -> Layout -> Paint -> Layout Tree -> Raster -> Compositor

其中知道LayoutTree生成，都是在UI Task Runner里面执行的，最后两步是在GPU Task Runner里面执行的。

其中Platform线程用于监听VSync信号，并发送到UI线程，驱动渲染管线运行。

然后UI线程用于生成LayoutTree，如果里面遇到图片，则交给IO线程去做图片解码，生成Texture，然后UI线程和IO线程数据丢给GPU线程做渲染。

其中IO线程和GPU线程是共享GL Context的。

调用satState方法，会告诉Platform去监听下一个vsync，然后Platform收到Native发过来的vsync信号后，开始生成RenderObject Tree，在做Layout，然后paint，然后生成Layout Tree。

### 3、State生命周期

initState：初始化阶段

build：经过初始化准备号State后，通过build投建

deactivate：state从视图树暂时删除，比如页面跳转切换

dispose: state从视图树永久移除

didUpdateConfig: Widget配置变化，比如热修复

setState: 需要更新视图，主动调用这个函数

### 4、MethodChannel详解

这个是基于Flutter v1.7.8+hotfix4版本源码阅读。

首先Flutter内置的channel类型有`BasicMessageChannel`、`MethodChannel`、`EventChannel`三种，在实现Native和Dart通信之前，我们必须初始化一个channel对象，该对象初始化必须包含3个参数，一个唯一的channel名称、实现<FlutterBinaryMessenger>协议的对象，一个可选的codec对象。

其中系统其实`FlutterEngine`实例就是实现了`FlutterBinaryMessenger`协议的对象，它被`BinaryMessengRelay`对象所弱持有。

##### BasicMessageChannel

该channel定义了最简单的双向消息发送能力，它提供了一个默认的`StandardMessageCodec`编码对象，codec是一个提供Native数据转成二进制数据的工具。

##### MethodChannel

该channel的调用过程和basic channel基本一样，唯一的区别是在之前加了一个FlutterMethodCall的包装/拆包，同时codec使用的是`StandardMethodCodec`。

##### EventChannel

该channel用于提供一种Flutter侧持续监听Native事件(数据)的能力。它只提供了一个`setStreamHandler:`接口。

在Flutter侧开始监听事件的时候，主动发起listen调用，并把一个block传给handler，handler保存该block，当需要发送数据时，通过调用该block发送数据给Flutter侧。

Native侧可以通过传送`FlutterEndOfEventStream`主动关闭该监听事件，也可以等Flutter侧调用`cancel`关闭该通道。

#### Codec

从整理上来看，在channel中数据流动涉及两个不同的系统，数据需要从Native的数据类型转成二进制，从Flutter到Native又要把数据从二进制转成Native的数据，这就是`MessageCodec`和`MethodCodec`的主要作用。其中二进制格式又分为`原始二进制`和`协议二级制`。

##### 原始二进制和协议二进制的区别

原始二进制主要涉及的类有`BinaryCodec`、`StringCodec`、`JSONMessageCodec`、`StandMessageCodec`4个编解码器。

- `BinaryCodec`: 提供了NSData和NSData相互编码/解码的能力
- `StringCodec`: 提供了NSString和NSData相互编码/解码的能力
- `JSONMessageCodec`: 提供了NSArray/NSDictionary和NSData相互编码/解码的能力。对于简单的顶级json数据(true、false、null、10等)，会将其自动编码/解码成NSArray类型。
- `StandardMessageCodec`能力依赖于`FlutterStandardWriter`和`FlutterStandardReader`。

还有一个是`JSONMethodCodec`方法，它的作用是调用方法/结果返回的编码/解码实现(FlutterMethodCall对象)。它的底层是依赖`StandarMessageCodec`的。

协议二级制主要涉及的类有`FutterStandardWriter`、`FlutterStandardReader`。该类提供了把基础Native对象，编码成协议二进制数据的能力。`协议二进制`是Flutter默认的channel交互的数据格式。

> 协议的格式大致如下，第一个字节是定义该二进制数据，代表Native的数据格式，第二个字节是可选字节，代表数据长度，然后根一段可选的字节对齐0。最后的内容是Native这里真实的值。

支持的类型如下，比如Dart侧为null，Native侧为nil，那么type就是0x00，Dart侧是true，Native侧是YES，则type是0x01，

目前主要支持的类型如下：

`null-nil, true-YES, false-NO, int-Int, int-Long, double-double, String-NSString，Uint8List-FlutterStandardTypedData typedDataWithBytes:`等。

##### 细节

1. Native侧二进制数据传给Flutter之前，会使用Dart_Handler进行数据转换。Dart_Handler是一个不透明间接指针，指向的是Dart堆上的对象。
2. Flutter启动的时候会做一个大堆绑定工作，在runApp方法内会先调用`WidgetsFlutterBinding.ensureInitialized()`方法，该方法会构造一个`WidgetsFlutterBinding`单例，`WidgetsFlutterBinding`继承自`BindingBase`，又mixin了一大堆Binding类(比如ServiceBinding、GestureBinding等)，然后就会分别调用这些Binding的`initInstance`和`initServiceExtensions`方法。在`ServiceBinding`里面，会把window的`onPlatformMessage`方法赋值未`defaultBinaryMassenger`内的`handlePlatformMessage`方法。
3. Handler是如何注册到defaultBinaryMessenger的？

### 5、FlutterBoost源码阅读

// TODO: 补全

### 6、Flutter路由底层实现

##### push过程

1. 首先我们推入Naviation的是一个Route对象，具体的来说，有好几种Route，比如OverlayRouter、ModalRouter；
2. 然后Navigator其实是一个Widget，如果用的是系统的MaterialApp，那么会自动帮我们生成一个Navigator Widget并且插入到整个Widget树里面；
3. Navigator的逻辑其实都在NavigatorState里面，里面其实有个一个Route列表，里面维护了你以为的页面栈，同时还有一个Overlay列表；
4. 然后在真正调用Navigator的push方法时，会从history里面拿出上一个Route，同时拿到老的route对应的OverlayEntry，同时传给要推的route，让当前route往上插入内容。
5. 然后调用navigator的overlay对象的`insert:above:`方法，把当前Route对应的Overlay查到lastOverlayEntry上面。
6. 在Router对应的OverlayEntry列表里面一般持有了两个OverlayEntry，一个是遮罩，一个是界面本身；
7. 我们再看OverlayEntry插入到Overlay所持有的列表里面后，首先会让overlay和当前的overlayEntry做关联，后面overlayEntry移除的时候要用到overlay对象；
8. 然后是调用Overlay的setState方法，触发OverlayState的`build`方法；
9. 然后就是所谓的剧院模式，首先创建两个列表，一个叫`onStageChildren`、一个是`offStageChildren`，其中onStage方法表示将要被绘制的，offStage方法不用被绘制的；
10. 然后倒序遍历，然后分配哪些群众上台，哪些群众观看，开始时opaque是`true`，直到遇到某个`opaque`为`false`，那么后面的OverlayEntry就是是offStage的了；
11. 然后上面加入队列的，是`_OverlayEntry`对象，不是`OverlayEntry`对象，其实就是通过`OverlayEntry`对象转成widget对象；
12. 然后offStage的OverlayEntry看他们是`maintainState`是否是true，如果是false，则直接销毁；
13. 分配好之后，返回一个`_Theatre`对象，表示喜剧开演，包装到`Stack`widget下面；
14. 至此，页面推送结束，后面就是等Vsync信号，等待构造生成Element树、RenderObject树，在做layout，paint，变成layer tree，最后提交到GPU线程渲染；

##### pop过程

1. 取出_history里面的最后一个元素，那是一个route实例；
2. 然后调用route实例的的`didPop`方法，其中调用的是`OverlayRoute`的`didPop`方法，然后是会进入`overlayRoute`的dispose方法；
3. dispose方法里面，就是遍历`_overlayEntries`，就是我们前面讲的一个是遮罩，一个是页面本身，overlayEntry对象，然后调用entry的remove方法；
4. entry的`remove`方法里面，先拿出关联的`overlay`对象，然后调用`overlay`的remove方法，同时传入当前overlayEntry实例;
5. 在`overlay`对象的`remove`方法里面，先从`entries`列表里面移除当前的entry，同时调用setState方法；

### 7、Flutter各种key

key主要用在Flutter页面更新的时候，Element Tree做diff判断依据，像StatelessWidgets它比较的时候比对的是runtimeType，如果一致，对应的Element不会重新生成，只调用widget的build方法重新获取配置信息，由于颜色值是写在widget里面的，所有可以正常更新。而Stateful Widget的颜色一般都放在state对象里面，state对象时被element对象持有的，而由于两个stateful widgets的runtime类型是一致的，那么其实就是跑一下widget里面的build方法，颜色都不是不会变的。但是设置了key之后，做diff的时候就能发现两个widget是不一样的，就会对element做交换了。

##### 细节

Flutter的diff算法，针对不同的组件采取不同的比较算法，比如Column，它比较的是Column里面children类型的runtimeType和key，然后再比较Children里面的内容是否相同。

##### key的种类

key有个基础工厂类key，同时基于这个key生出了两种类型的key，LocalKey和GlobalKey。基于LocalKey又实现了ValueKey、ObjectKey、UniqueKey，ValueKey下面又分PageStorageKey。

其中GlobalKey实现比较简单，它用了一个全局的静态常量Map来保存它对应的Element。可以通过GlobalKey找到持有该GlobalKey的widget、State和Element。

ValueKey其实很简单，就是通过一个字符串去标记是否相同，如果两个字符串相同，则认为这个ValueKey相同。

ObjectKey根据2点判断两个key是否相同，第一是runtimeType，其实是通过Object的value去判断是否相同。

UniqueKey是生成一个唯一的key，它永远只等于它自己。

GlobalKey常用于在外面引用内部的某一个widget，或者再内部拿某一个widget的state，然后在根据该state去做一些事情。比如我们常用的Navigator就是通过GlobalKey去管理的。