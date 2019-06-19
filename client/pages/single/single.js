// pages/single/single.js
const app = getApp()
var config = require("../common/config.js")
var WxParse = require('../../wxParse/wxParse.js')
// 在页面中定义插屏广告
let interstitialAd = null
Page({

  /**
   * 页面的初始数据
   */
  data: {},

  /**
   * 生命周期函数--监听页面加载
   */
  loadContent: function(chapter, content) {
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
        content: content
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
        try {
          WxParse.wxParse('article', 'html', dat.content, that, 5)
        } catch (err) {
          if (content == true)
            that.loadContent(chapter, false)
          wx.showModal({
            title: '提示',
            content: "html显示出错，可能由于此站点RSS并不是全文输出, 正在显示RSS描述内容",
            showCancel: false
          })
          return
        }
        that.setData({
          "chapter": chapter
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
  },
  onLoad: function (options) {
    console.log(options)
    // 在页面onLoad回调事件中创建插屏广告实例
    if (wx.createInterstitialAd) {
      interstitialAd = wx.createInterstitialAd({
        adUnitId: 'adunit-a85c2d50a5793f7a'
      })
      interstitialAd.onLoad(() => { })
      interstitialAd.onError((err) => { })
      interstitialAd.onClose(() => { })
    }
    if (interstitialAd) {
      interstitialAd.show().catch((err) => {
        console.error(err)
      })
    }
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
      this.loadContent(chapter, true)
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
  },

  bindchange: function(e) {
    console.log("swipper-change")
    console.log(e)
  }
})
