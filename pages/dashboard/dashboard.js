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

  touchX:0, 
  delwidth:100,
  touchS: function(e) {
    console.log("touchS" + e)
    if (e.touches.length != 1)
      return ;
    this.touchX = e.touches[0].clientX
  },

  touchM: function(e) {
    console.log("touchM" + e)
    if (e.touches.length != 1)
      return ;
    var moveX = e.touches[0].clientX;
    var deltaX = moveX - this.touchX;
    var style = "right:0px"
    if (deltaX < 0) {//move left
      deltaX = -deltaX;
      if (deltaX > this.delwidth)
        deltaX = this.delwidth;
      style = "right:" + deltaX + "px"
    } else if (deltaX > 0) {//move right

    } else {
      return
    }
    var idx = e.target.dataset.index
    if (idx == undefined)
      return
    var k = "rss[" + idx.toString() + "].style"
    console.log(k, style)
    var param = {}
    param[k] = style
    this.setData(param)
  },

  touchE: function(e) {

  },

})