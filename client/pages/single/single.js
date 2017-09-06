// pages/single/single.js
const app = getApp()

Page({

  /**
   * 页面的初始数据
   */
  data: {
    chapter: [
      {
        title: "hello",
        content: "C程序中让两个不同版本的库共存"
      }, {
        title: "world",
        content: '<p>今天<a href="http://nonblock.cn/" title="">有同学</a>提出，如何在一个C程序中让两个不同版本的库共存。</p>'+
        '<p>今天<a href="http://nonblock.cn/" title="">有同学</a>提出，如何在一个C程序中让两个不同版本的库共存。</p>'+
	'<p>首先想到的方案是，把其中一个版本的库函数全部重命名，比如把每一个函数名都加一个_v2的后缀。</p>'+
	'<p>人工替换到没什么，但是如果函数个数超过10个，就有点不拿人当人使了。</p>'+
	'<p>而使有工具去替换就会遇到一些棘手的问题，如何识别哪些是函数，哪些是系统函数（系统函数不需要添加后缀)等。</p>'+
	'<p>随后想到的另一个解决方案是C++的方案，为其中一个版本库中的所有文件添加命名空间。然后使用g++将这部分代码编译成.o文件，之后再使用gcc将这些.o文件与整个程序中的其他代码进行链接。</p>'+
	'<p>不过需要注意的是，g++编译后所有导出接口名都会变化得不那么直观。</p>'+
	'<hr/>'+
	'第三种方案完全解决了以上两种方案的痛点。</p>'+
	'<p>考虑一个C语言的编译链接过程。</p>'+
	'<p>首先会将每个c文件编译成.o文件。</p>'+
	'<p>在编译过程中，导出函数并不会被实际分配地址，而是将函数名以F符号的方式存在.o文件的符号表中。</p>'+
	'<p>在本c文件调用的函数如果不存在于本文件，也会生成一个UND的符号存在.o文件的符号表中。</p>'+
	'<p>在链接过程中，链接器接收输入的.o文件，为每个.o文件中的符号分存地址，并生成可执行文件。</p>'+
	'<p>有了这几点事实，问题就变得的简单多了。</p>'+
	'<p>首先将其中一个版本的库中所有代码编译为.o文件。然后收集所有.o文件中的F符号。</p>'+
	'<p>由于整个库代码有内部依赖关系，收集到的F符号必然是所有.o文件中UND符号的超集。</p>'+
	'<p>换句话说，所有的F符号名就是我们要重命名的所有函数名。</p>'+
	'<p>这里我们需要借助objdump和objcopy工具。objdump -t 用于列表.o文件的符号表，objcopy用于重命名符号。</p>'+
	'<p>我随手写了一段用于过虑F符号的lua脚本</p>'+
	'<pre class="brush: lua; title: ; notranslate">'+
	'--rename.lua'+
	'local list = {}'+
	'local reg = &quot;([^%s]+)%s+([^%s]+)%s+([^%s]+)&quot;..'+
	'	&quot;%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)&quot;'+
	'for l in io.stdin:lines() do'+
	'	local a,b,c,d,e,f = string.match(l, reg)'+
	'	if a and c == &quot;F&quot; then'+
	'		list[#list + 1] = &quot; --redefine-sym &quot;'+
	'		list[#list + 1] = string.format(&quot;%s=%s_v2&quot;, f, f)'+
	'	end'+
	'end'+
	'print(&quot;#/bin/sh&quot;)'+
	'print(&quot;objcopy &quot; .. table.concat(list) .. &quot; $1&quot;)'+
	'</pre>'+
	'<p>我们可以使用如下命令来收集所有.o文件的F符号, 并产生修改符号所用的脚本</p>'+
	'<pre class="brush: plain; title: ; notranslate">'+
	'find . -name "*.o" | xargs objdump -t | ./lua rename &gt; rename.sh'+
	'</pre>'+
	'<p>现在我们只需要再执行一条命令就可以把所有函数名增加一个_v2的后缀.</p>'+
	'<pre class="brush: plain; title: ; notranslate">'+
	'find . -name "*.o" | xargs -n 1 sh ./rename.sh'+
	'</pre>'+
	'<p>至此，我们这个版本的库代码的所有函数名已经全部增加了_v2后缀。</p>'+
	'<p>这些被处理过的.o文件与我们将所有.c代码中函数名重命名之后编译出的.o文件完全一等价。</p>'+
	'<hr/>'+
	'<p>8月2号补充：</p>'+
	'<p>在实际使用中发现, 局部函数(static 函数)符号有可能会被gcc做修饰，将被修饰的符号重命名会给我们带来一些麻烦，而我们原本也不需要去处理局部函数。</p>'+
	'<p>因此对rename.lua做如下修改，过虑掉非全局符号：</p>'+
	'<pre class="brush: lua; title: ; notranslate">'+
	'--rename.lua'+
	'local list = {}'+
	'local reg = &quot;([^%s]+)%s+([^%s]+)%s+([^%s]+)&quot;..'+
	'	&quot;%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)&quot;'+
	'for l in io.stdin:lines() do'+
	'	local a,b,c,d,e,f = string.match(l, reg)'+
	'	if a and c == &quot;F&quot; and b == &quot;g&quot; then'+
	'		list[#list + 1] = &quot; --redefine-sym &quot;'+
	'		list[#list + 1] = string.format(&quot;%s=%s_v2&quot;, f, f)'+
	'	end'+
	'end'+
	'print(&quot;#/bin/sh&quot;)'+
	'print(&quot;objcopy &quot; .. table.concat(list) .. &quot; $1&quot;)'+
	'</pre><p>首先想到的方案是，把其中一个版本的库函数全部重命名，比如把每一个函数名都加一个_v2的后缀。</p>'+
	'	< p > 人工替换到没什么，但是如果函数个数超过10个，就有点不拿人当人使了。</p>'+
	'	< p > 而使有工具去替换就会遇到一些棘手的问题，如何识别哪些是函数，哪些是系统函数（系统函数不需要添加后缀)等。</p>'+
	'	< p > 随后想到的另一个解决方案是C++的方案，为其中一个版本库中的所有文件添加命名空间。然后使用g++将这部分代码编译成.o文件，之后再使用gcc将这些.o文件与整个程序中的其他代码进行链接。</p>'+
	'	< p > 不过需要注意的是，g++编译后所有导出接口名都会变化得不那么直观。</p>'+
	'	< hr />'+
	'	第三种方案完全解决了以上两种方案的痛点。</p>'+
	'	      < p > 考虑一个C语言的编译链接过程。</p>'+
	'		< p > 首先会将每个c文件编译成.o文件。</p>'+
	'		  < p > 在编译过程中，导出函数并不会被实际分配地址，而是将函数名以F符号的方式存在.o文件的符号表中。</p>'+
	'		    < p > 在本c文件调用的函数如果不存在于本文件，也会生成一个UND的符号存在.o文件的符号表中。</p>'+
	'		      < p > 在链接过程中，链接器接收输入的.o文件，为每个.o文件中的符号分存地址，并生成可执行文件。</p>'+
	'			< p > 有了这几点事实，问题就变得的简单多了。</p>'+
	'			  < p > 首先将其中一个版本的库中所有代码编译为.o文件。然后收集所有.o文件中的F符号。</p>'+
	'			    < p > 由于整个库代码有内部依赖关系，收集到的F符号必然是所有.o文件中UND符号的超集。</p>'+
	'			      < p > 换句话说，所有的F符号名就是我们要重命名的所有函数名。</p>'+
	'				< p > 这里我们需要借助objdump和objcopy工具。objdump - t 用于列表.o文件的符号表，objcopy用于重命名符号。</p>'+
	'				  < p > 我随手写了一段用于过虑F符号的lua脚本 < /p>'+
	'				  < pre class="brush: lua; title: ; notranslate" >'+
	'				    --rename.lua'+
	'local list = {}'+
	'local reg = &quot; ([^%s] +)% s + ([^%s] +)% s + ([^%s] +)& quot;..'+
	'	&quot;%s + ([^%s] +)% s + ([^%s] +)% s + ([^%s] +)& quot;'+
	'for l in io.stdin:lines() do'+
	'  local a, b, c, d, e, f = string.match(l, reg)'+
	'	if a and c == &quot; F & quot; then'+
	'list[#list + 1] = &quot; --redefine - sym & quot;'+
	'list[#list + 1] = string.format(&quot;%s=%s_v2 & quot;, f, f)'+
	'end'+
	'end'+
	'print(&quot;#/bin/sh & quot;)'+
	'print(&quot;objcopy & quot; .. table.concat(list).. &quot; $1 & quot;)'+
	'</pre>'+
	'  < p > 我们可以使用如下命令来收集所有.o文件的F符号, 并产生修改符号所用的脚本 < /p>'+
	'  < pre class="brush: plain; title: ; notranslate" >'+
	'    find. -name "*.o" | xargs objdump - t | ./lua rename & gt; rename.sh'+
	'      < /pre>'+
	'      < p > 现在我们只需要再执行一条命令就可以把所有函数名增加一个_v2的后缀.</p>'+
	'      < pre class="brush: plain; title: ; notranslate" >'+
	'	find. -name "*.o" | xargs - n 1 sh ./rename.sh'+
	'	  < /pre>'+
	'	  < p > 至此，我们这个版本的库代码的所有函数名已经全部增加了_v2后缀。</p>'+
	'	    < p > 这些被处理过的.o文件与我们将所有.c代码中函数名重命名之后编译出的.o文件完全一等价。</p>'+
	'	      < hr />'+
	'	      <p>8月2号补充：</p>'+
	'		< p > 在实际使用中发现, 局部函数(static 函数)符号有可能会被gcc做修饰，将被修饰的符号重命名会给我们带来一些麻烦，而我们原本也不需要去处理局部函数。</p>'+
	'		  < p > 因此对rename.lua做如下修改，过虑掉非全局符号：</p>'+
	'		    < pre class="brush: lua; title: ; notranslate" >'+
	'		      --rename.lua'+
	'local list = {}'+
	'local reg = &quot; ([^%s] +)% s + ([^%s] +)% s + ([^%s] +)& quot;..'+
	'	&quot;%s + ([^%s] +)% s + ([^%s] +)% s + ([^%s] +)& quot;'+
	'for l in io.stdin:lines() do'+
	'  local a, b, c, d, e, f = string.match(l, reg)'+
	'	if a and c == &quot; F & quot; and b == &quot; g & quot; then'+
	'list[#list + 1] = &quot; --redefine - sym & quot;'+
	'list[#list + 1] = string.format(&quot;%s=%s_v2 & quot;, f, f)'+
	'end'+
	'end'+
	'print(&quot;#/bin/sh & quot;)'+
	'print(&quot;objcopy & quot; .. table.concat(list).. &quot; $1 & quot;)'+
	'</pre>"'
      }
    ]
  },

  /**
   * 生命周期函数--监听页面加载
   */
  onLoad: function (options) {

  },

  /**
   * 生命周期函数--监听页面初次渲染完成
   */
  onReady: function () {

  },

  /**
   * 生命周期函数--监听页面显示
   */
  onShow: function () {

  },

  /**
   * 生命周期函数--监听页面隐藏
   */
  onHide: function () {

  },

  /**
   * 生命周期函数--监听页面卸载
   */
  onUnload: function () {

  },

  /**
   * 页面相关事件处理函数--监听用户下拉动作
   */
  onPullDownRefresh: function () {

  },

  /**
   * 页面上拉触底事件的处理函数
   */
  onReachBottom: function () {

  },

  /**
   * 用户点击右上角分享
   */
  onShareAppMessage: function () {

  }
})
