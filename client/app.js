//app.js
var config = require('./pages/common/config.js')
App({
  globalData: {
    userInfo: null,
    chapter: null,
  },
  savechapter:function (ch) {
    this.globalData.chapter = ch
  },
  getuid: function() {
    var uid = wx.getStorageSync("uid")
    console.log("getuid:" + uid)
    if (uid == "" || uid == undefined) {
      wx.showModal({
        title: '获取用户ID',
        content: '无法获取用户ID，请重新授权登录',
        showCancel: false
      })
      return null
    }
    return uid
  },
  login: function(func) {
    var uid = wx.getStorageSync("uid")
    if (uid != "" && uid != undefined) { //already login
      if (func != undefined)
        func()
      return
    } 
    var url_ = config.requrl + "/userinfo/getid"
    wx.login({
      success: res => {
        console.log("code:"+res.code)
        wx.request({
          url: url_,
          data: {
            code: res.code
          },
          header: {
            'content-type': 'application/json'
          },
          dataType: "json",
          success: function (res) {
            var dat = res.data
            console.log("uid", dat.uid)
            console.log(res)
            wx.setStorageSync("uid", dat.uid)
            wx.hideLoading()
            if (func != undefined)
              func()
          },
          fail: function (res) {
            console.log(res)
          }
        })
      }
    }),
    wx.showLoading({
      "title": "登录中",
      mask: true
    })
  },
  onLaunch: function () {
    this.login()
    // 已经授权，可以直接调用 getUserInfo 获取头像昵称，不会弹框
    wx.getUserInfo({
      success: res => {
        // 可以将 res 发送给后台解码出 unionId
        this.globalData.userInfo = res.userInfo
        if (this.userInfoReadyCallback) {
          this.userInfoReadyCallback(res)
        }
      }
    })
  }
})