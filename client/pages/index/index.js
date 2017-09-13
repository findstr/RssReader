//index.js
//获取应用实例
const app = getApp()
var config = require("../common/config.js")

Page({
  data: {
    more:true,
    chapter:[]
  },
  //事件处理函数
  bindViewTap: function() {
    wx.navigateTo({
      url: '../logs/logs'
    })
  },
  onLoad: function () {
    var that = this
    app.login(function () {
      that.refreshFrom(0)
    })
  },

  refreshIdx: 0,
  refreshFrom:function (idx, func) {
    var url_ = config.requrl + "/page/get"
    var uid = app.getuid()
    var that = this
    wx.request({
      url: url_,
      method: "POST",
      data: {
        uid: uid,
        index: idx,
      },
      dataType: "json",
      success: function (res) {
        var dat = res.data
        console.log(dat)
        for (var i = 0; i < dat.length; i++) {
          dat[i].style = "chapter-item"
        }
        var dst
        if (idx == 0)
          dst = dat
        else
          dst = that.data.chapter.concat(dat)
        that.setData({
          "chapter": dst
        })
        that.refreshIdx = idx + dat.length
        console.log("refresh:" + idx + ":" + that.refreshIdx + ":" + that.data.chapter.length)
        wx.hideLoading()
        if (func != undefined)
          func()
      },
      fail: function (res) {
        console.log(res)
      }
    })
    wx.showLoading({
      title: '数据加载中',
      mask:true
    })
  },

  /**
   * 页面相关事件处理函数--监听用户下拉动作
   */
  onPullDownRefresh: function () {
    this.refreshIdx = 0
    console.log("pullUpper")
    this.refreshFrom(0, function() {
      wx.stopPullDownRefresh()
    })
  },

  onShow: function() {
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
    var touchid = this.touched
    if (touchid == null)
      return
    this.setClass(this.touched, "chapter-item")
    this.touched = null
    if (this.ctrl_jump)
      return
    this.ctrl_jump = true
    var that = this
    app.savechapter(this.data.chapter)
    var url_ = "../single/single?" + "id=" + touchid
    var chapter = this.data.chapter[touchid];
    console.log(chapter)
    if (chapter.read == false) {
      var mark_url_ = config.requrl + "/page/read"
      var uid = app.getuid()
      wx.request({
        url: mark_url_,
        method: "POST",
        data: {
          uid: uid,
          cid: chapter.cid,
        },
      })
      var param = {}
      param['chapter['+touchid+'].read'] = true
      that.setData(param)
    }
    wx.navigateTo({
      url: url_
    })
  }

})
