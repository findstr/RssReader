// pages/dashboard/dashboard.js
Page({
  /**
   * 页面的初始数据
   */
  data: {
    rss:[
      { title: "你好",
        subtitle: "我是副标题",
        url: "http://hello",
        style:"left:0px"
      },
      {
        title: "世界",
        subtitle: "我是副标题",
        url: "http://world",
        style:"left:0px"
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

  },
  //logic
  rss_subscribe_url:"",

  onRssInput: function(e) {
    this.rss_subscribe_url = e.detail.value
  },
  onRemove: function(e) {
    var idx = e.target.dataset.index
    this.resetItem(-1)  //force reset
    var rss = this.data.rss
    rss.splice(idx, 1)
    this.setData({"rss":rss})
    console.log("onRemove", idx)
  },

  onSave: function(e) {
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
    var rss = this.data.rss
    var l = rss.length
    rss[l] = {
      title: "新增",
      subtitle: "第:"+l,
      url: url,
      style: "left:0px"
    }
    this.setData({"rss":rss})
  },

  //ui effect
  touchX:0,
  touchIndex:null,
  itemPos:0,
	//const
  delwidth:100,
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
