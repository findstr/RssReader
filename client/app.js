//app.js
var config = require('./pages/common/config.js')
App({
  globalData: {
    userInfo: null
  },
  login: function() {
    /*
    var uid = wx.getStorageSync("uid")
    if (uid != "")  //already login
      return
    */
    var url_ = config.requrl + "/userinfo/getid"
    wx.login({
      success: res => {
        console.log("code:"+res.code)
        wx.request({
          //url: "https://weixin.gotocoding.com/userinfo/getid",
          //url: "http://blog.gotocoding.com/test.json",
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
          },
          fail: function (res) {
            console.log(res)
          }
        })
      }
    }),
    wx.showLoading({
      "title": "登录中"
    })
  },
  onLaunch: function () {
    // 展示本地存储能力
    var logs = wx.getStorageSync('logs') || []
    logs.unshift(Date.now())
    wx.setStorageSync('logs', logs)
    // 登录
    this.login()
  }
})