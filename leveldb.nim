import options, leveldb/raw

proc free(p: pointer) {.importc.}

type
  LevelDb* = ref object
    db: ptr leveldb_t
    syncWriteOptions: ptr leveldb_writeoptions_t
    asyncWriteOptions: ptr leveldb_writeoptions_t
    readOptions: ptr leveldb_readoptions_t

  LevelDbException* = object of Exception

const
  levelDbTrue = cuchar(1)
  levelDbFalse = cuchar(0)

proc checkError(errPtr: cstring) =
  if errPtr != nil:
    defer: free(errPtr)
    raise newException(LevelDbException, $errPtr)

proc close*(self: LevelDb) =
  if self.db == nil:
    return
  leveldb_close(self.db)
  leveldb_writeoptions_destroy(self.syncWriteOptions)
  leveldb_writeoptions_destroy(self.asyncWriteOptions)
  leveldb_readoptions_destroy(self.readOptions)
  self.db = nil

proc open*(path: string): LevelDb =
  new(result, close)

  let options = leveldb_options_create()
  leveldb_options_set_create_if_missing(options, levelDbTrue)
  defer: leveldb_options_destroy(options)

  result.syncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.syncWriteOptions, levelDbTrue)
  result.asyncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.asyncWriteOptions, levelDbFalse)
  result.readOptions = leveldb_readoptions_create()

  var errPtr: cstring = nil
  result.db = leveldb_open(options, path, addr errPtr)
  checkError(errPtr)

proc put*(self: LevelDb, key: string, value: string, sync = true) =
  assert self.db != nil
  var errPtr: cstring = nil
  let writeOptions = if sync: self.syncWriteOptions else: self.asyncWriteOptions
  leveldb_put(self.db, writeOptions,
              key, key.len.csize, value, value.len.csize, addr errPtr)
  checkError(errPtr)

proc get*(self: LevelDb, key: string): Option[string] =
  var size: csize
  var errPtr: cstring = nil
  let s = leveldb_get(self.db, self.readOptions, key, key.len, addr size, addr errPtr)
  checkError(errPtr)

  if s == nil:
    result = none(string)
  else:
    result = some($s)
    free(s)

proc delete*(self: LevelDb, key: string, sync = true) =
  var errPtr: cstring = nil
  let writeOptions = if sync: self.syncWriteOptions else: self.asyncWriteOptions
  leveldb_delete(self.db, writeOptions, key, key.len, addr errPtr)
  checkError(errPtr)

proc getIterData(iterPtr: ptr leveldb_iterator_t): (Option[string], Option[string]) =
  var len: csize
  var str: cstring

  str = leveldb_iter_key(iterPtr, addr len)
  if len > 0:
    result[0] = some ($str)[0..<len]
  else:
    result[0] = none string

  str = leveldb_iter_value(iterPtr, addr len)
  if len > 0:
    result[1] = some ($str)[0..<len]
  else:
    result[1] = none string

iterator iter*(self: LevelDb, seek: string = "", reverse: bool = false): (
    string, string) =
  var iterPtr = leveldb_create_iterator(self.db, self.readOptions)
  defer: leveldb_iter_destroy(iterPtr)

  if seek.len > 0:
    leveldb_iter_seek(iterPtr, seek, seek.len)
  else:
    if reverse:
      leveldb_iter_seek_to_last(iterPtr)
    else:
      leveldb_iter_seek_to_first(iterPtr)

  while true:
    if leveldb_iter_valid(iterPtr) == levelDbFalse:
      break

    var (key, value) = getIterData(iterPtr)
    var err: cstring = nil
    leveldb_iter_get_error(iterPtr, addr err)
    checkError(err)
    yield (key.get(), value.get())

    if reverse:
      leveldb_iter_prev(iterPtr)
    else:
      leveldb_iter_next(iterPtr)

when isMainModule:
  let db = leveldb.open("test.db")
  db.put("hello", "world")
  echo db.get("nothing")
  echo db.get("hello")
  db.delete("hello")
  echo db.get("hello")

  db.put("aaa", "1")
  db.put("aba", "2")
  db.put("abb", "3")

  echo ">> iter"
  for i in db.iter:
    echo i

  echo ">> iter reverse"
  for i in db.iter(reverse = true):
    echo i

  echo ">> iter seek ab"
  for i in db.iter(seek = "ab"):
    echo i

  echo ">> iter seek ab reverse"
  for i in db.iter(seek = "ab", reverse = true):
    echo i
