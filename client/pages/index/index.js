//index.js
//获取应用实例
const app = getApp()
var config = require("../common/config.js")

Page({
  data: {
    more:true,
    chapter:[],
    chapter_display:[],
    filter_type: 1,//1 显示所有，2 显示未读 3 显示已读
    filter_title:"显示所有文章列表",
    filter_hide: true,
    filter_name: [
      { text: "显示所有文章列表", bindtap: "showAll" },
      { text: "显示未读文章列表", bindtap: "showUnread" },
      { text: "显示已读文单列表", bindtap: "showReaded" }
    ]
  },

  FilterSheetTap: function () {
    var typ = wx.setStorageSync("filter_type", this.data.filter_type)
    this.setData({
      filter_hide: !this.data.filter_hide
    })
  },
  setFilterSilence: function(typ) {
    //1 显示所有，2 显示未读 3 显示已读
    this.setData({ "filter_type": typ, "filter_title": this.data.filter_name[typ - 1].text })
    this.refreshDisplay()
  },
  setFilter: function(typ) {
    //1 显示所有，2 显示未读 3 显示已读
    this.setData({ "filter_type": typ, "filter_title": this.data.filter_name[typ - 1].text })
    this.FilterSheetTap()
    this.refreshDisplay()
  },
  showAll: function () {
    this.setFilter(1)
  },
  showUnread: function () {
    this.setFilter(2)
  },
  showReaded: function () {
    this.setFilter(3)
  },
  FilterSheetCancel: function() {
    this.FilterSheetTap()
  },

  onLoad: function () {
    var that = this
    app.login(function () {
      var typ = wx.getStorageSync("filter_type")
      if (typ != undefined && typ != "")
        that.setFilterSilence(typ)
      that.refreshFrom(0, function() {
        that.refreshDisplay()
      })
    })
  },

  onShow: function () {
    this.refreshDisplay()
  },

  refreshDisplay: function() {
    var t = this.data.filter_type
    console.log("t:"+t)
    if (t == 1) {//显示所有
      this.setData({"chapter_display": this.data.chapter})
    } else {
      var chapter = this.data.chapter
      var display = new Array(chapter.length)
      var push = 0
      for (var i = 0; i < chapter.length; i++) {
        var item = chapter[i]
        if (!item.read && t == 2) {//显示未读
          display[push] = item
          push++;
        } else if ((item.read) && t == 3) {//显示已读
          display[push] = item
          push++;
        }
      }
      var display = display.slice(0, push)
      console.log("push:" + push + ":" + chapter.length + ":" + display.length)
      this.setData({ "chapter_display": display })
    }
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
        for (var i = idx; i < dat.length + idx; i++)
          dat[i].index = i
        if (idx == 0) {
          dst = dat
        } else {
          dst = that.data.chapter.concat(dat)
        }
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
    var that = this
    console.log("pullUpper")
    this.refreshFrom(0, function() {
      that.refreshDisplay()
      wx.stopPullDownRefresh()
    })
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
    var chapter = this.data.chapter_display[touchid];
    console.log("readed:")
    console.log(chapter)
    var url_ = "../single/single?" + "id=" + chapter.index
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
      param['chapter[' + chapter.index +'].read'] = true
      that.setData(param)
    }
    wx.navigateTo({
      url: url_
    })
  },
  onShareAppMessage: function () {

  }

})
