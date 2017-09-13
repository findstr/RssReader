// pages/dashboard/dashboard.js
var config = require ("../common/config.js")
const app = getApp()

Page({
  /**
   * 页面的初始数据
   */
  data: {
    rss:[]
  },

  refreshList: function() {
    var uid = app.getuid()
    if (uid == null)
      return
    var that = this
    var url_ = config.requrl + "/rsslist/get"
    wx.request({
      url: url_,
      data: {
        uid: uid
      },
      method: 'POST',
      dataType: "json",
      success: function (res) {
        var dat = res.data
        console.log(dat)
        that.setData({
          "rss": dat
        })
        wx.hideLoading()
      },
      fail: function (res) {
        console.log(res)
      }
    })
    wx.showLoading({
      title: '加载中',
      mask: true
    })
  },

  formSubmit: function(e) {
    var that = this
    var url_ = config.requrl + "/notice/subscribe"
    wx.request({
      url: url_,
      data: {
        uid: 0,
        formid: e.detail.formId
      },
      method: 'POST',
    })
  },

  /**
   * 生命周期函数--监听页面显示
   */
  onShow: function () {
    var that = this
    app.login(function() {
      that.refreshList()
    })
  },

  /**
   * 页面相关事件处理函数--监听用户下拉动作
   */
  onPullDownRefresh: function () {
    this.refreshList()
  },

  /**
   * 用户点击右上角分享
   */
  onShareAppMessage: function () {

  },
  //logic
  rss_subscribe_url:"",

  onRssInput: function(e) {
    this.rss_subscribe_url = e.detail.value
  },
  onRemove: function(e) {
    var that = this
    var uid = app.getuid()
    var idx = e.target.dataset.index
    this.resetItem(-1)  //force reset
    var rss = this.data.rss
    var item = rss[idx]
    var url_ = config.requrl + "/rsslist/del"
    console.log("rssid", item.rssid)
    wx.request({
      url: url_,
      method: "POST",
      data: {
        rssid: item.rssid,
        uid: uid
      },
      header: {
        'content-type': 'application/json'
      },
      dataType: "json",
      success: function (res) {
        if (res.statusCode != 200) {
          wx.showModal({
            title: '提示',
            content: res.data.errmsg,
            showCancel: false
          })
        } else {
          rss.splice(idx, 1)
          that.setData({ "rss": rss })
        }
        wx.hideLoading()
      },
      fail: function (res) {
        console.log(e)
      }
    })
    console.log("onRemove", idx)
  },

  onSave: function(e) {
    var that = this
    this.resetItem(-1)  //force reset
    var url = this.rss_subscribe_url
    console.log("onSave:" + url)
    if (url == "") {
      wx.showModal({
        title: '提示',
        content: '请输入要订阅的RSS地址',
        showCancel: false
      })
      return
    }
    var uid = app.getuid()
    if (uid == null)
      return
    console.log("save:" + uid)
    var url_ = config.requrl + "/rsslist/add"
    wx.login({
      success: res => {
        console.log("code:" + res.code)
        wx.request({
          url: url_,
          method: "POST",
          data: {
            rss: url,
            uid: uid
          },
          header: {
            'content-type': 'application/json'
          },
          dataType: "json",
          success: function (res) {
            console.log(res)
            if (res.statusCode == 200) {
              var len = that.data.rss.length
              var param = {}
              param["rss[" + len + "]"] = res.data
              console.log(res)
              that.setData(param)
            } else {
              wx.showModal({
                title: '提示',
                content: res.data.errmsg,
                showCancel: false
              })
            }
            wx.hideLoading()
          },
          fail: function (res) {
            console.log(res)
          }
        })
      }
    })
    wx.showLoading({
      "title": "保存中",
      mask: true
    })
  },

  //ui effect
  touchX:0,
  touchIndex:null,
  itemPos:0,
	//const
  delwidth:60,
  updateSpeed:10,
  setPos: function (idx, x) {
    console.log("setPos:"+idx)
    this.itemPos = x
    var style = "right:" + x + "px"
    var k = "rss[" + idx.toString() + "].style"
    var param = {}
    param[k] = style
    this.setData(param)
  },

	addPos: function(idx, x) {
		this.itemPos += x
    if (this.itemPos > this.delwidth)
      this.itemPos = this.delwidth
    else if (this.itemPos < 0)
      this.itemPos = 0
    this.setPos(idx, this.itemPos)
	},

  resetItem: function(idx) {
    var pos = this.itemPos;
    if (this.touchIndex == null)
      return
    if (this.touchIndex == idx)
      return
    this.setPos(this.touchIndex, 0)
		this.touchIndex = null
    this.itemPos = 0
	},

  updateMove: function() {
		var dir
		if (this.itemPos < this.delwidth / 2) {
			dir = -1
		} else {
			dir = 1
		}
		this.addPos(this.touchIndex, dir * this.updateSpeed)
  },

  touchS: function(e) {
    if (e.touches.length != 1)
      return ;
    var idx = e.target.dataset.index
    if (idx == undefined)
      return
		this.resetItem(idx)
    this.touchX = e.touches[0].clientX
  },

  touchM: function(e) {
    if (e.touches.length != 1)
      return ;
		var idx = e.target.dataset.index
    if (idx == undefined)
      return
    var moveX = e.touches[0].clientX
    var deltaX = moveX - this.touchX
		this.touchX = moveX
		this.touchIndex = idx
		this.addPos(idx, -deltaX)
  },

  touchE: function(e) {
		if (this.itemPos == 0) {
			this.touchIndex = null
			return
		}
    var that = this
    var func = function() {
      var pos = that.itemPos;
        if (pos == 0 || that.itemPos == that.delwidth)
        return
      that.updateMove()
      setTimeout(func, 30)
    }
		func()
  },

})
