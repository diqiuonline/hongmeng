/**
 * 龙空 GraphQL 文档。
 *
 * 只保留客户端实际使用的操作：
 * - Login：账号密码登录
 * - GetMe：首页版块导航
 * - GetUserPunch：获取签到状态
 * - Punch：每日签到
 * - ViewForumPage：版块帖子分页
 * - ViewThread：帖子详情与楼层
 */

export const LOGIN_MUTATION = `mutation Login($email: String!, $password: String!) {
  login(email: $email, password: $password) {
    uid
    name
    twoWay
    serverTime
  }
}`;

export const GET_USER_PUNCH_QUERY = `query GetUserPunch {
  userPunch(uid: 0) {
    isPunch
    punchallday
    punchday
    punchhighestday
  }
}`;

export const PUNCH_MUTATION = `mutation Punch {
  punch {
    uid
    punchday
    isPunch
    punchhighestday
    punchallday
  }
}`;

export const GET_ME_QUERY = `query GetMe {
  me {
    uid
    name
    avatar
  }
  commonNavbars {
    type
    name
    fid
    num
    link
  }
}`;

export const THREAD_COMPONENT_FRAGMENT = `fragment threadComponent on Thread {
  tid
  title
  fid
  dateline
  lastpost
  digest
  highlight
  author {
    name
    uid
    avatar
  }
  replies
  views
  status
  lock
  first
  page
  forum {
    name
  }
  tags {
    id
    name
  }
}`;

export const VIEW_FORUM_PAGE_QUERY = `query ViewForumPage($fid: Int!, $page: Int, $action: String) {
  threads(fid: $fid, action: $action, page: $page) {
    ...threadComponent
  }
}
${THREAD_COMPONENT_FRAGMENT}`;

/**
 * 楼层只需要浏览相关字段，避免请求引用、评分等无关数据。
 */
export const POST_LIST_FRAGMENT = `fragment postListComponent on Query {
  posts(tid: $tid, page: $page, pid: $pid, authorid: $authorid) {
    lou
    pid
    content
    dateline
    user {
      uid
      name
      avatar
    }
  }
}`;

export const VIEW_THREAD_QUERY = `query ViewThread($tid: Int!, $page: Int, $pid: String, $authorid: Int) {
  thread(tid: $tid, authorid: $authorid, pid: $pid) {
    ...threadComponent
  }
  ...postListComponent
}
${THREAD_COMPONENT_FRAGMENT}
${POST_LIST_FRAGMENT}`;