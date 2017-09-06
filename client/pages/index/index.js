//index.js
//获取应用实例
const app = getApp()

Page({
  data: {
    chapter:[
      {
        title:"C程序中让两个不同版本的库共存",
        abs: "今天有同学提出，如何在一个C程序中让两个不同版本的库共存。 首先想到的方案是，把其中一个版本的库函数全部重命名",
        style: "chapter-item"
      },{
        title: "标题1",
        abs: "为了",
        style: "chapter-item"
      }
    ]
  },
  //事件处理函数
  bindViewTap: function() {
    wx.navigateTo({
      url: '../logs/logs'
    })
  },
  onLoad: function () {
   
  },
  onShow: function() {
    app.login()
  },
  //logic
  ctrl_jump:false,
  onHide: function () {
    this.ctrl_jump = false
    console.log("onHide")
  },

  touched:null,
  setClass: function(idx, style) {
    var param = {}
    var k = "chapter[" + idx.toString() + "].style"
    param[k] = style
    this.setData(param)
  },
  touchS: function(e) {
    var idx = e.target.dataset.index
    if (idx == undefined)
      return ;
    this.setClass(idx, "chapter-item-select")
    this.touched = idx
    console.log("Start")
  },
  touchM: function(e) {
    var idx = this.touched
    if (idx == undefined)
      return;
    if (idx == null)
      return
    this.setClass(idx, "chapter-item")
    this.touched = null
  },
  touchE: function(e) {
    if (this.touched == null)
      return
    this.setClass(this.touched, "chapter-item")
    this.touched = null
    if (this.ctrl_jump)
      return
    this.ctrl_jump = true
    wx.navigateTo({
      url: '../single/single'
    })
  }

})
