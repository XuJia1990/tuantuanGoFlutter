class TuanTuanEndpoints {
  static const dictData = '/app-api/system/dict-data/type';
  static const sendSmsCode = '/app-api/member/auth/send-sms-code';
  static const validateSmsCode = '/app-api/member/auth/validate-sms-code';
  static const smsRegister = '/app-api/member/auth/sms-register';
  static const smsLogin = '/app-api/member/auth/sms-login';
  static const passwordLogin = '/app-api/member/auth/login';
  static const logout = '/app-api/member/auth/logout';
  static const updatePassword = '/app-api/member/user/update-password';
  static const resetPassword = '/app-api/member/user/reset-password';
  static const userDetail = '/app-api/member/user/get';
  static const version = '/app-api/go/version-info/getVersion_1_2_0';
  static const privacy = '/app-api/go/privacy/get';
  static const updateUser = '/app-api/member/user/update';
  static const inquirySend = '/app-api/go/inquiry/send';
  static const deleteUser = '/app-api/member/user/delete';
  static const isGroupManager = '/app-api/go/group-info/isGroupManager';

  static const areaTree = '/app-api/system/area/tree';
  static const stationList = '/app-api/go/station-info/getStationList';
  static const stationListCoupon =
      '/app-api/go/station-info/getStationListCoupon';
  static const shopListMain = '/app-api/go/shop-info/getShopListMain';
  static const category = '/app-api/go/category-info/getCategory';
  static const search = '/app-api/go/redis/search';
  static const shopInfo = '/app-api/go/shop-info/getShopInfo';
  static const couponPage = '/app-api/go/coupon-info/page';
  static const couponPageMain = '/app-api/go/coupon-info/pageMain';
  static const couponInfo = '/app-api/go/coupon-info/getCouponInfo';
  static const insertShopFav = '/app-api/go/shop-fav/insertShopFav';
  static const deleteShopFav = '/app-api/go/shop-fav/deleteShopFav';
  static const shopFavList = '/app-api/go/shop-fav/getShopList';
  static const insertRating = '/app-api/go/shop-rating/insertRatingInfo';
  static const createOrder = '/app-api/go/order-mgmt/create';
  static const payInfo = '/app-api/go/order-mgmt/payinfo';
  static const deleteOrder = '/app-api/go/order-mgmt/delete';
  static const payStatus = '/app-api/go/order-mgmt/paystatus';
  static const orderPage = '/app-api/go/order-mgmt/page';
  static const orderDetail = '/app-api/go/order-mgmt/get';
  static const writeOff = '/app-api/go/order-mgmt/updatewriteoffstatus';

  static const memberCardList = '/app-api/go/member-info/getMemberCardList';
  static const shopMemberList = '/app-api/go/member-info/getShopMemberList';
  static const memberOrderList = '/app-api/go/member-order/getMemberOrderList';
  static const memberOrderListByShop =
      '/app-api/go/member-order/getMemberOrderListByShopId';
  static const pointRate = '/app-api/go/apppointRate/get';
  static const createMember = '/app-api/go/member-order/create_1_2_0';
  static const chargeMember = '/app-api/go/member-order/charge';
  static const refundOrder = '/app-api/go/member-order/refund';
  static const payOrder = '/app-api/go/member-order/pay';
  static const scanUserPayCode = '/app-api/go/member-order/scanUserPayCode';
  static const checkoutInfo = '/app-api/go/appCheckOutInfo/get';
  static const memberUsedHistory =
      '/app-api/go/member-order/getMemberUsedHistoryList_1_2_0';
  static const checkMember = '/app-api/go/member-info/checkMember';
  static const checkPayPassword = '/app-api/go/member-info/checkPayPassword';
  static const setPayPassword = '/app-api/go/member-info/setPayPassword';
  static const payPasswordStatus =
      '/app-api/go/member-info/getPayPasswordStatus';
  static const managerGroupList =
      '/app-api/go/group-info/getManagerGroupInfoList';
  static const userGroupList = '/app-api/go/group-info/getUserGroupInfoList';
  static const createPayCode = '/app-api/go/member-order/createPayCode';
  static const payByShopManager = '/app-api/go/member-order/payByShopManger';
  static const adInfo = '/app-api/go/ad-info/getAdInfo';
  static const wechatChargeOrderStatus =
      '/app-api/go/member-order/getWechatChargeOrderStatus';
  static const discountTypeList =
      '/app-api/go/category-info/getDiscountTypeList';
  static const chargeTypeList = '/app-api/go/category-info/getChargeTypeList';
}
