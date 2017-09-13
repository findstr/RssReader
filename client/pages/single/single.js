// pages/single/single.js
const app = getApp()
var config = require("../common/config.js")
var WxParse = require('../../wxParse/wxParse.js')

Page({

  /**
   * 页面的初始数据
   */
  data: {},

  /**
   * 生命周期函数--监听页面加载
   */
  onLoad: function (options) {
    console.log(options)
    var chapter = app.globalData.chapter[options.id]
    var content = chapter.content
    console.log("onLoad" + chapter.content)
    console.log(chapter)
    if (content != undefined) {
      this.setData({
        "chapter":chapter
      })
      WxParse.wxParse('article', 'html', app.globalData.chapter[options.id].content, this, 5)
    } else {
      var url_ = config.requrl + "/page/detail"
      var uid = app.getuid()
      var cid = chapter.cid
      var that = this
      console.log("start")
      wx.request({
        url: url_,
        method: "POST",
        data: {
          uid: uid,
          cid: cid,
        },
        dataType: "json",
        success: function (res) {
          console.log(res)
          var dat = res.data
          chapter.content = dat.content
          chapter.author = dat.author
          chapter.date = dat.date
          chapter.link = dat.link
          wx.hideLoading()
          WxParse.wxParse('article', 'html', dat.content, that, 5)
          that.setData({
            "chapter":chapter
          })
        },
        fail: function (res) {
          console.log(res)
        }
      })
      wx.showLoading({
        title: '数据加载中',
        mask: true
      })
    }    
  },

  docopy: function() {
    var ch = this.data.chapter
    if (ch == undefined)
      return
    if (ch.link == undefined)
      return
    wx.setClipboardData({
      data: ch.link,
      success: function (res) {
        wx.showToast({
          title: '已复制文章链接',
          icon: 'success',
          duration: 1000
        })
      }
    })
    console.log("url:" + ch)
  },

  bindchange: function(e) {
    console.log("swipper-change")
    console.log(e)
  }
})
