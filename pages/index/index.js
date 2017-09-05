//index.js
//获取应用实例
const app = getApp()

Page({
  data: {
    chapter:[
      {
        title:"标题",
        abs: "为了适应广大的前端开发者，我们的 WXSS 具有 CSS 大部分特性。 同时为了更适合开发微信小程序，我们对 CSS 进行了扩充以及修改。",
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
    if (app.globalData.userInfo) {
      this.setData({
        userInfo: app.globalData.userInfo,
        hasUserInfo: true
      })
    } else if (this.data.canIUse){
      // 由于 getUserInfo 是网络请求，可能会在 Page.onLoad 之后才返回
      // 所以此处加入 callback 以防止这种情况
      app.userInfoReadyCallback = res => {
        this.setData({
          userInfo: res.userInfo,
          hasUserInfo: true
        })
      }
    } else {
      // 在没有 open-type=getUserInfo 版本的兼容处理
      wx.getUserInfo({
        success: res => {
          app.globalData.userInfo = res.userInfo
          this.setData({
            userInfo: res.userInfo,
            hasUserInfo: true
          })
        }
      })
    }
  },
  getUserInfo: function(e) {
    console.log(e)
    app.globalData.userInfo = e.detail.userInfo
    this.setData({
      userInfo: e.detail.userInfo,
      hasUserInfo: true
    })
  },

  //logic
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
    wx.navigateTo({
      url: '../single/single'
    })
  }

})
