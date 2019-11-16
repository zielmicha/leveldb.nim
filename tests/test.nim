import unittest, options, sequtils
import leveldb, leveldb/raw

suite "leveldb":

  setup:
    let env = leveldb_create_default_env()
    let dbName = $(leveldb_env_get_test_directory(env))
    let db = leveldb.open(dbName)

  teardown:
    db.close()
    removeDb(dbName)

  test "version":
    let (major, minor) = getLibVersion()
    check(major > 0)
    check(minor > 0)

  test "get nothing":
    check(db.get("nothing") == none(string))

  test "put and get":
    db.put("hello", "world")
    check(db.get("hello") == some("world"))

  test "delete":
    db.put("hello", "world")
    db.delete("hello")
    check(db.get("hello") == none(string))

  proc initData(db: LevelDb) =
    db.put("aa", "1")
    db.put("ba", "2")
    db.put("bb", "3")

  test "iter":
    initData(db)
    check(toSeq(db.iter()) == @[("aa", "1"), ("ba", "2"), ("bb", "3")])

  test "iter reverse":
    initData(db)
    check(toSeq(db.iter(reverse = true)) ==
          @[("bb", "3"), ("ba", "2"), ("aa", "1")])

  test "iter seek":
    initData(db)
    check(toSeq(db.iter(seek = "ab")) ==
          @[("ba", "2"), ("bb", "3")])

  test "iter seek reverse":
    initData(db)
    check(toSeq(db.iter(seek = "ab", reverse = true)) ==
          @[("ba", "2"), ("aa", "1")])

  test "iter prefix":
    initData(db)
    check(toSeq(db.iterPrefix(prefix = "b")) ==
          @[("ba", "2"), ("bb", "3")])

  test "iter range":
    initData(db)
    check(toSeq(db.iterRange(start = "a", limit = "ba")) ==
          @[("aa", "1"), ("ba", "2")])

  test "iter range reverse":
    initData(db)
    check(toSeq(db.iterRange(start = "bb", limit = "b")) ==
          @[("bb", "3"), ("ba", "2")])
