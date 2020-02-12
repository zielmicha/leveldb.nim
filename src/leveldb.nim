import options, strutils, leveldb/raw

type
  LevelDb* = ref object
    path*: string
    db: ptr leveldb_t
    syncWriteOptions: ptr leveldb_writeoptions_t
    asyncWriteOptions: ptr leveldb_writeoptions_t
    readOptions: ptr leveldb_readoptions_t
    cache: ptr leveldb_cache_t

  LevelDbBatch* = ref object
    batch: ptr leveldb_writebatch_t

  LevelDbException* = object of Exception

const
  levelDbTrue = uint8(1)
  levelDbFalse = uint8(0)

  version* = "0.3.0"

proc free(p: pointer) {.importc.}

proc checkError(errPtr: cstring) =
  if errPtr != nil:
    defer: free(errPtr)
    raise newException(LevelDbException, $errPtr)

proc getLibVersion*(): (int, int) =
  result[0] = leveldb_major_version()
  result[1] = leveldb_minor_version()

proc close*(self: LevelDb) =
  if self.db == nil:
    return
  leveldb_close(self.db)
  leveldb_writeoptions_destroy(self.syncWriteOptions)
  leveldb_writeoptions_destroy(self.asyncWriteOptions)
  leveldb_readoptions_destroy(self.readOptions)
  if self.cache != nil:
    leveldb_cache_destroy(self.cache)
    self.cache = nil
  self.db = nil

proc open*(path: string, create = true, reuse = true, paranoidChecks = true,
    cacheCapacity = 0, blockSize = 4 * 1024, writeBufferSize = 4*1024*1024,
    maxOpenFiles = 1000, maxFileSize = 2 * 1024 * 1024,
    restartInterval = 16): LevelDb =
  new(result, close)

  let options = leveldb_options_create()
  defer: leveldb_options_destroy(options)

  result.syncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.syncWriteOptions, levelDbTrue)
  result.asyncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.asyncWriteOptions, levelDbFalse)
  result.readOptions = leveldb_readoptions_create()

  if create:
    leveldb_options_set_create_if_missing(options, levelDbTrue)
  else:
    leveldb_options_set_create_if_missing(options, levelDbFalse)
  if reuse:
    leveldb_options_set_error_if_exists(options, levelDbFalse)
  else:
    leveldb_options_set_error_if_exists(options, levelDbTrue)
  if paranoidChecks:
    leveldb_options_set_paranoid_checks(options, levelDbTrue)
  else:
    leveldb_options_set_paranoid_checks(options, levelDbFalse)

  leveldb_options_set_write_buffer_size(options, writeBufferSize)
  leveldb_options_set_block_size(options, blockSize)
  leveldb_options_set_max_open_files(options, cast[cint](maxOpenFiles))
  leveldb_options_set_max_file_size(options, maxFileSize)
  leveldb_options_set_block_restart_interval(options,
                                             cast[cint](restartInterval))

  if cacheCapacity > 0:
    let cache = leveldb_cache_create_lru(cacheCapacity)
    leveldb_options_set_cache(options, cache)
    result.cache = cache

  var errPtr: cstring = nil
  result.path = path
  result.db = leveldb_open(options, path, addr errPtr)
  checkError(errPtr)

proc put*(self: LevelDb, key: string, value: string, sync = true) =
  assert self.db != nil
  var errPtr: cstring = nil
  let writeOptions = if sync: self.syncWriteOptions else: self.asyncWriteOptions
  leveldb_put(self.db, writeOptions,
              key, key.len.csize, value, value.len.csize, addr errPtr)
  checkError(errPtr)

proc newString(cstr: cstring, length: csize): string =
  result = newString(length)
  copyMem(unsafeAddr result[0], cstr, length)

proc get*(self: LevelDb, key: string): Option[string] =
  var size: csize
  var errPtr: cstring = nil
  let s = leveldb_get(self.db, self.readOptions, key, key.len, addr size, addr errPtr)
  checkError(errPtr)

  if s == nil:
    result = none(string)
  else:
    result = some (newString(s, size))
    free(s)

proc delete*(self: LevelDb, key: string, sync = true) =
  var errPtr: cstring = nil
  let writeOptions = if sync: self.syncWriteOptions else: self.asyncWriteOptions
  leveldb_delete(self.db, writeOptions, key, key.len, addr errPtr)
  checkError(errPtr)

proc destroy*(self: LevelDbBatch) =
  if self.batch == nil:
    return
  leveldb_writebatch_destroy(self.batch)
  self.batch = nil

proc newBatch*(): LevelDbBatch =
  new(result, destroy)
  result.batch = leveldb_writebatch_create()

proc put*(self: LevelDbBatch, key: string, value: string, sync = true) =
  leveldb_writebatch_put(self.batch, key, key.len.csize, value, value.len.csize)

proc append*(self, source: LevelDbBatch) =
  leveldb_writebatch_append(self.batch, source.batch)

proc delete*(self: LevelDbBatch, key: string) =
  leveldb_writebatch_delete(self.batch, key, key.len.csize)

proc clear*(self: LevelDbBatch) =
  leveldb_writebatch_clear(self.batch)

proc write*(self: LevelDb, batch: LevelDbBatch) =
  var errPtr: cstring = nil
  leveldb_write(self.db, self.syncWriteOptions, batch.batch, addr errPtr)
  checkError(errPtr)

proc getIterData(iterPtr: ptr leveldb_iterator_t): (Option[string], Option[string]) =
  var len: csize
  var str: cstring

  str = leveldb_iter_key(iterPtr, addr len)
  if len > 0:
    result[0] = some (newString(str, len))
  else:
    result[0] = none string

  str = leveldb_iter_value(iterPtr, addr len)
  if len > 0:
    result[1] = some (newString(str, len))
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

iterator iterPrefix*(self: LevelDb, prefix: string): (string, string) =
  for (key, value) in iter(self, prefix, reverse = false):
    if key.startsWith(prefix):
      yield (key, value)
    else:
      break

iterator iterRange*(self: LevelDb, start, limit: string): (string, string) =
  let reverse: bool = limit < start
  for (key, value) in iter(self, start, reverse = reverse):
    if reverse:
      if key < limit:
        break
    else:
      if key > limit:
        break
    yield (key, value)

proc removeDb*(name: string) =
  var err: cstring = nil
  let options = leveldb_options_create()
  leveldb_destroy_db(options, name, addr err)
  checkError(err)

proc repairDb*(name: string) =
  let options = leveldb_options_create()
  leveldb_options_set_create_if_missing(options, levelDbFalse)
  leveldb_options_set_error_if_exists(options, levelDbFalse)
  var errPtr: cstring = nil
  leveldb_repair_db(options, name, addr errPtr)
  checkError(errPtr)

when isMainModule:
  import os

  proc usage() =
    echo "LevelDB client"
    echo ""
    echo "Usage:"
    echo "  leveldb [-d <db_path>] create"
    echo "  leveldb [-d <db_path>] get <key> [-x | --hex]"
    echo "  leveldb [-d <db_path>] put <key> <value> [-x | --hex]"
    echo "  leveldb [-d <db_path>] list [-x | --hex]"
    echo "  leveldb [-d <db_path>] keys"
    echo "  leveldb [-d <db_path>] delete <key>"
    echo "  leveldb [-d <db_path>] repair"
    echo "  leveldb -h | --help"
    echo "  leveldb -v | --version"
    echo ""
    echo "Options:"
    echo "  -d --database  Database path"
    echo "  -x --hex       binary value in uppercase hex"
    echo "  -h --help      Show this screen"
    echo "  -v --version   Show version"
    quit()

  var args = commandLineParams()

  if "-h" in args or "--help" in args or len(args) == 0:
    usage()

  if "-v" in args or "--version" in args:
    echo "leveldb.nim ", version
    let (major, minor) = getLibVersion()
    echo "leveldb ", major, ".", minor
    quit()

  proc findArg(s: seq[string], item: string): int =
    result = find(s, item)
    let stop = find(s, "--")
    if stop >= 0 and stop <= result:
      result = -1

  var dbPath = "./"
  var i = findArg(args, "-d")
  var j = findArg(args, "--database")
  if i >= 0 and j >= 0:
    quit("Please specify database path one time only.")
  i = max(i, j)
  if i >= 0:
    if (i + 1) < len(args):
      dbPath = args[i+1]
      args.delete(i+1)
      args.delete(i)
    else:
      quit("Please specify database path.")

  var hex = false
  i = findArg(args, "-x")
  j = findArg(args, "--hex")
  if i >= 0:
    hex = true
    args.delete(i)
  if j >= 0:
    hex = true
    args.delete(j)

  # drop stop word
  if "--" in args:
    args.delete(args.find("--"))

  if len(args) == 0:
    usage()

  proc checkCommand(args: seq[string], requires: int) =
    if len(args) < requires + 1:
      quit("Command " & args[0] & " requires at least " & $(requires) & " arguments.")

  import strutils

  var db: LevelDb
  var key, value: string
  if args[0] == "create":
    db = open(dbPath)
    db.close()
  elif args[0] == "get":
    checkCommand(args, 1)
    db = open(dbPath)
    key = args[1]
    let val = db.get(key)
    if val.isNone():
      quit()
    else:
      if hex:
        echo val.get().toHex()
      else:
        echo val.get()
    db.close()
  elif args[0] == "put":
    checkCommand(args, 2)
    db = open(dbPath)
    key = args[1]
    value = args[2]
    if hex:
      value = parseHexStr(value)
    db.put(key, value)
    db.close()
  elif args[0] == "list":
    db = open(dbPath)
    for (key, value) in db.iter():
      if hex:
        echo key, " ", value.toHex()
      else:
        echo key, " ", value
    db.close()
  elif args[0] == "keys":
    db = open(dbPath)
    for (key, value) in db.iter():
      echo key
    db.close()
  elif args[0] == "delete":
    checkCommand(args, 1)
    db = open(dbPath)
    key = args[1]
    db.delete(key)
    db.close()
  elif args[0] == "repair":
    repairDb(dbPath)
