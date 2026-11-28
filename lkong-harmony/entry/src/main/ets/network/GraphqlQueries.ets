/**
 * 龙空 GraphQL 文档。
 *
 * 注意：GetMe 操作名被服务端用作未登录版块导航白名单，不可改名。
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

export const VIEW_HOT_THREADS_QUERY = `query ViewHotThreads {
  hots: threadsFragment(fid: 0, type: "hot") {
    tid
    title
    author
    authorid
  }
}`;

export const VIEW_FORUM_HOT_THREADS_QUERY = `query ViewForumHotThreads($fid: Int!) {
  hots: threadsFragment(fid: $fid, type: "hot") {
    tid
    title
    author
    authorid
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
 * 楼层列表包含正文与 quote 引用楼层结构。
 */
export const POST_LIST_FRAGMENT = `fragment postListComponent on Query {
  posts(tid: $tid, page: $page, pid: $pid, authorid: $authorid) {
    lou
    pid
    content
    dateline
    quote {
      pid
      status
      content
      author {
        uid
        name
      }
    }
    user {
      uid
      name
      avatar
    }
    rate {
      id
      pid
      num
      reason
      dateline
      user {
        uid
        name
        avatar
      }
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

export const SEARCH_THREADS_QUERY = `query SearchThreads($text: String!, $sort: String!, $searchAfter: String) {
  searchThreads(text: $text, sort: $sort, searchAfter: $searchAfter) {
    searchAfter
    hasMore
    threads {
      tid
      title
      forum {
        fid
        name
      }
      author {
        name
        uid
      }
      dateline
      replies
      views
    }
  }
}`;

export const SEARCH_FORUMS_QUERY = `query SearchForums($text: String!) {
  searchForums(text: $text) {
    fid
    name
    avatar
    followers
    threads
    isFollow
  }
}`;

export const SEARCH_USERS_QUERY = `query SearchUsers($text: String!) {
  searchUsers(text: $text) {
    uid
    name
    isFollow
    followers
    avatar
    verify {
      info
      type
    }
  }
}`;

export const VIEW_USER_PROFILE_PAGE_QUERY = `query ViewUserProfilePage($uid: Int!, $page: Int) {
  user(uid: $uid) {
    uid
    name
    adminLevel
    dateline
    points
    avatar
    gender
    verify {
      type
      info
    }
    status
    isFollow
  }
  userCount(uid: $uid) {
    uid
    followings
    followers
    digests
    posts
    threads
    money
    gems
    vertyInfo
    level {
      name
      color
      num
    }
  }
  content: userThreads(uid: $uid, page: $page) {
    ...threadComponent
  }
}
${THREAD_COMPONENT_FRAGMENT}`;

export const VIEW_USER_THREADS_PAGE_QUERY = `query ViewUserThreadsPage($uid: Int!, $page: Int) {
  content: userThreads(uid: $uid, page: $page) {
    ...threadComponent
  }
}
${THREAD_COMPONENT_FRAGMENT}`;

export const MIX_POST_COMPONENT_FRAGMENT = `fragment MixPostComponent on MixPost {
  authorid
  author {
    uid
    name
    avatar
  }
  dateline
  content
  pid
  __typename
  ... on MajorPost {
    thread {
      tid
      title
      replies
      fid
      forumName
    }
  }
  ... on MajorReply {
    thread {
      tid
      title
      authorid
      author {
        uid
        name
      }
    }
  }
  ... on MinorPost {
    quote {
      pid
      author {
        uid
        name
      }
      content
    }
    thread {
      tid
      fid
    }
  }
  ... on MajorBookReview {
    thread {
      tid
      replies
    }
    score
    book {
      bid
      title
      author
    }
  }
  ... on MajorBookReviewReply {
    thread {
      tid
      title
      author {
        uid
        name
      }
    }
    book {
      bid
      title
    }
  }
}`;

export const VIEW_USER_POSTS_PAGE_QUERY = `query ViewUserContentsPage($uid: Int!, $isDigest: Boolean!, $page: Int) {
  content: userReplies(uid: $uid, isDigest: $isDigest, page: $page) {
    ...MixPostComponent
  }
}
${MIX_POST_COMPONENT_FRAGMENT}`;

export const VIEW_USER_FAVORITE_GROUPS_QUERY = `query ViewUserFavoriteGroups($uid: Int!) {
  content: userFavoriteGroupList(uid: $uid) {
    id
    title
    count
    uid
    isPublic
    description
    dateline
  }
}`;

export const VIEW_FAVORITE_GROUP_DETAIL_QUERY = `query ViewFavoriteGroup($groupid: Int!, $page: Int) {
  collection: userFavoriteGroup(groupid: $groupid) {
    id
    title
    count
    uid
    isPublic
    description
    dateline
  }
  comments: userFavoriteList(gid: $groupid, page: $page) {
    authorid
    author {
      uid
      name
      avatar
    }
    dateline
    content
    pid
    __typename
    ... on MajorPost {
      thread {
        tid
        title
        replies
        fid
        forumName
      }
    }
    ... on MajorReply {
      thread {
        tid
        title
        authorid
        author {
          uid
          name
        }
      }
    }
    ... on MinorPost {
      thread {
        tid
        fid
      }
    }
    ... on MajorBookReview {
      thread {
        tid
        replies
      }
      book {
        bid
        title
        author
      }
    }
    ... on MajorBookReviewReply {
      thread {
        tid
        title
        author {
          uid
          name
        }
      }
      book {
        bid
        title
      }
    }
  }
}`;

export const MY_FAVORITE_GROUP_LIST_QUERY = `query MyFavoriteGroupList($tid: Int!, $pid: String!) {
  myFavoriteGroupList(tid: $tid, pid: $pid) {
    id
    title
    isPublic
    hasFavorited
  }
}`;

export const FAVORITE_POST_MUTATION = `mutation FavoritePost($groupid: Int!, $pid: String!, $tid: Int!, $undo: Boolean) {
  favoritePost(groupid: $groupid, pid: $pid, tid: $tid, undo: $undo) {
    ok
  }
}`;

export const CREATE_FAVORITE_GROUP_MUTATION = `mutation CreateFavoriteGroup($title: String!, $description: String!, $isPublic: Boolean!) {
  createFavoriteGroup(title: $title, description: $description, isPublic: $isPublic) {
    id
    title
    isPublic
  }
}`;

export const EDIT_FAVORITE_GROUP_MUTATION = `mutation EditFavoriteGroup($groupid: Int!, $title: String!, $description: String!, $isPublic: Boolean!) {
  editFavoriteGroup(groupid: $groupid, title: $title, description: $description, isPublic: $isPublic) {
    ok
  }
}`;

export const DEL_FAVORITE_GROUP_MUTATION = `mutation DelFavoriteGroup($groupid: Int!) {
  delFavoriteGroup(id: $groupid) {
    ok
  }
}`;

export const REPLY_THREAD_MUTATION = `mutation Reply($tid: Int!, $content: String!, $pid: String) {
  replyThread(tid: $tid, content: $content, pid: $pid) {
    lou
    pid
    content
    dateline
    quote {
      pid
      status
      content
      author {
        uid
        name
      }
    }
    user {
      uid
      name
      avatar
    }
  }
}`;

export const NEW_THREAD_MUTATION = `mutation NewThread($fid: Int!, $title: String!, $content: String!) {
  postThread(fid: $fid, title: $title, content: $content) {
    tid
  }
}`;

export const RATE_POST_MUTATION = `mutation Rate($tid: Int!, $pid: String!, $num: Int!, $reason: String) {
  rate(tid: $tid, pid: $pid, num: $num, reason: $reason) {
    id
    pid
    num
    reason
    dateline
    user {
      uid
      name
      avatar
    }
  }
}`;

export const GET_NOTICE_COUNT_QUERY = `query GetNoticeCount {
  noticeCount {
    noticeCount
    fansCount
    rateCount
    atmeCount
    pmCount
  }
}`;

export const VIEW_NOTICES_QUERY = `query ViewNotices($date: Date) {
  notice(date: $date) {
    data: notices {
      id
      uid
      action
      content
      authorid
      author
      dateline
      fromid
    }
    hasMore
    nextDate
  }
}`;

export const VIEW_ATME_QUERY = `query ViewAtMe($date: Date) {
  atme(date: $date) {
    data: posts {
      authorid
      author {
        uid
        name
        avatar
      }
      dateline
      content
      pid
      __typename
      ... on MajorPost {
        thread {
          tid
          title
          replies
          fid
          forumName
        }
      }
      ... on MajorReply {
        thread {
          tid
          title
          authorid
          author {
            uid
            name
          }
        }
      }
      ... on MinorPost {
        thread {
          tid
          fid
        }
      }
      ... on MajorBookReview {
        thread {
          tid
          replies
        }
        book {
          bid
          title
        }
      }
      ... on MajorBookReviewReply {
        thread {
          tid
          title
          author {
            uid
            name
          }
        }
        book {
          bid
          title
        }
      }
    }
    hasMore
    nextDate
  }
}`;

export const VIEW_RATE_NOTICE_QUERY = `query ViewRateNotice($date: Date) {
  rateNotice(date: $date) {
    data: rates {
      uid
      rid
      tid
      pid
      title
      num
      user {
        uid
        name
      }
      dateline
    }
    hasMore
    nextDate
  }
}`;

export const VIEW_FANS_NOTICE_QUERY = `query ViewFansNotice($date: Date) {
  fansNotice(date: $date) {
    data: users {
      uid
      name
      isFollow
      avatar
      verify {
        info
        type
      }
    }
    hasMore
    nextDate
  }
}`;

export const TWO_WAY_LOGIN_MUTATION = `mutation TwoWayLogin($twoWay: String!, $code: String!, $serverTime: String!) {
  twoWaylogin(twoWay: $twoWay, code: $code, serverTime: $serverTime) {
    uid
    name
  }
}`;

export const BASE_POST_QUERY = `query BasePost($tid: Int!, $pid: String!) {
  thread(tid: $tid) {
    title
    first
  }
  post(tid: $tid, pid: $pid) {
    pid
    content
    authorid
    lock
  }
}`;

export const EDIT_POST_MUTATION = `mutation EditPost($tid: Int!, $pid: String!, $content: String!, $title: String) {
  editPost(tid: $tid, pid: $pid, content: $content, title: $title) {
    ok
    link
  }
}`;

export const FOLLOW_USER_MUTATION = `mutation FollowUser($uid: Int!, $follow: Boolean!) {
  followUser(uid: $uid, follow: $follow) {
    ok
  }
}`;

export const VIEW_LAST_USERS_MESSAGES_QUERY = `query ViewLastUsersMessages($date: Date) {
  lastUsersMessages(date: $date) {
    data: messages {
      user {
        uid
        name
        avatar
      }
      lastTime
      newCount
      content
    }
    hasMore
    nextDate
  }
}`;

export const DEL_USER_MESSAGE_MUTATION = `mutation DelUserMessage($toUid: Int!) {
  delUserMessage(toUid: $toUid) {
    ok
  }
}`;

export const VIEW_USER_MESSAGES_QUERY = `query ViewUserMessages($uid: Int!, $date: Date) {
  userMessages(touid: $uid, date: $date) {
    data: messages {
      content
      dateline
      id
      uid
    }
    hasMore
    nextDate
  }
}`;

export const SEND_MESSAGE_MUTATION = `mutation SendMessage($uid: Int!, $content: String!) {
  sendMessage(toUid: $uid, content: $content) {
    content
    dateline
    id
    uid
  }
}`;

export const SEND_IMAGE_MESSAGE_MUTATION = `mutation SendImageMessage($uid: Int!, $imageKey: String!) {
  sendImageMessage(toUid: $uid, imageKey: $imageKey) {
    content
    dateline
    id
    uid
  }
}`;

export const DEL_MESSAGE_MUTATION = `mutation DelMessage($uid: Int!, $id: String!) {
  delMessage(toUid: $uid, contentid: $id) {
    ok
  }
}`;