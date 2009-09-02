#! /usr/bin/env runhaskell

command line is
./HsSqlSystem.lhs [commandName] [commandArgs ...]

commands are:
loadsql
cleardb
clearandloadsql
lexfile
showfileatts
checkppp
roundtrip

command args:

loadsql [databasename] [filename]*
database must already exist, loads sql from files into database, via
parsing, checking and pretty printing

cleardb [databasename]
attempts to reset the database to empty, using a hack

clearandloadsql [databasename] [filename]*
runs cleardb then loadsql

lexfile [filename]
lexes the file given then displays each token on a separate line

showfileatts [filename]
parses then runs the attribute grammar processor over the ast,
displays all the values produced

checkppp [filename]
parses then pretty prints then parses the pretty printed output. Used
to check a file can parse, and that pretty printing then parsing gives
you the same ast.

roundtrip [filename] [targetfilename]

getfntables [databasename]
output function and operator tables for the parser and type checker
from the given database


TODO 1: add options to specify username and password (keep optional though)
TODO 2: think of a name for this command

> import System
> import System.IO
> import Control.Monad
> import System.Directory
> import Data.List

> import Parser
> import DatabaseLoader
> import Lexer
> import Ast
> import PrettyPrinter
> import DBAccess
> import ArgsParser

================================================================================

= main

> main :: IO ()
> main = do
>   --do this to avoid having to put flushes everywhere when we
>   --provide "..." progress thingys, etc.
>   hSetBuffering stdout NoBuffering
>   args <- getArgs
>   when (length args == 0) $ error "no command given"
>   case () of
>     _ | (length args == 2 && head args == "cleardb") -> cleardb (args !! 1)
>       | (length args >= 3 && head args == "loadsql") -> loadsqlfiles args
>       | (length args >= 3 && head args == "clearandloadsql") ->
>            cleardb (args !! 1) >> loadsqlfiles args
>       | (length args == 2 && head args == "lexfile") -> lexFile (args !! 1)
>       | (length args >= 2 && head args == "showfileatts") -> showfileatts (tail args)
>       | (length args >= 2 && head args == "parsefile") -> parseFile (tail args)
>       | (length args == 3 && head args == "roundtrip") -> roundTripFile (tail args)
>       | (length args == 2 && head args == "getfntables") -> getFnTables (args !! 1)
>       | (length args == 2 && head args == "gettypestuff") -> getTypeStuff (args !! 1)
>       | (length args == 1 && head args == "checkfntypes") -> checkFnTypes
>       | otherwise -> error "couldn't parse command line"
>   where
>     loadsqlfiles args = mapM_ (loadSqlfile (args !! 1)) (tail $ tail args)


================================================================================

= load sql file

This takes a file full of sql from the disk and loads it into the
database given.

> loadSqlfile :: String -> String -> IO ()
> loadSqlfile db fn = do
>   res <- parseSqlFileWithState fn
>   case res of
>     Left er -> error $ show er
>     Right ast -> putStrLn ("loading " ++ fn)
>                  >> loadIntoDatabase db fn ast

================================================================================

= small hack utility to help with testing

TODO: use the correct username in this command
TODO: do something more correct

> cleardb :: String -> IO ()
> cleardb db = do
>   withConn ("dbname=" ++ db) $ \conn -> do
>     runSqlCommand conn "drop owned by jake cascade;"
>   putStrLn $ "database " ++ db ++ " cleared."


================================================================================

> lexFile :: FilePath -> IO ()
> lexFile f = do
>   putStrLn $ "lexing " ++ show f
>   x <- lexSqlFile f
>   return ()
>   case x of
>        Left er -> print er
>        Right l -> mapM_ print l

================================================================================

> showfileatts :: [String] -> IO ()
> showfileatts = mapM_ pf
>   where
>     pf f = do
>       putStrLn $ "parsing " ++ show f
>       x <- parseSqlFileWithState f
>       case x of
>            Left er -> print er
>            Right st -> do
>                mapM_ print st
>                putStrLn "\nchecking ast"
>                let y = checkAst st
>                print y
>       return ()

================================================================================

Routine to parse sql from a file, check that it appears to parse ok,
that pretty printing it and parsing that text gives the same ast,
and then displays the pretty printed version so you can see how well it's
done (maybe it could interpolate each original statement with its
parsed, pretty printed version so you can more easily check how
authentic the sql is and how much has been silently dropped on the floor

> parseFile :: [String] -> IO ()
> parseFile = mapM_ pf
>   where
>     pf f = do
>       putStrLn $ "parsing " ++ show f
>       x <- parseSqlFileWithState f
>       case x of
>            Left er -> print er
>            Right st -> do
>                --print l
>                --putStrLn "END OF AST END OF AST END OF AST END OF AST END OF AST END OF AST"
>                putStrLn "parse ok"
>                print st
>                let pp = printSql st
>                --putStrLn pp
>                --check roundtrip
>                case parseSql pp of
>                  Left er -> error $ "roundtrip failed: " ++ show er
>                  Right st' -> if resetSps' st == resetSps' st'
>                                then putStrLn "roundtrip ok"
>                                else putStrLn "roundtrip failed: different ast"
>       return ()

================================================================================

Used to test the parsing and pretty printing round trip. Takes two
arguments, a source filename and a target filename. If the target file
exists, it quits. Parses the source file then pretty prints it to the
target filename.

> roundTripFile :: [FilePath] -> IO ()
> roundTripFile args = do
>   when (length args /= 2) $
>          error "Please pass exactly two filenames, source and target."
>   let (source:target:[]) = args
>   targetExists <- doesFileExist target
>   when targetExists $
>          error "the target file name exists already, please delete it or choose a new filename"
>   x <- parseSqlFile source
>   case x of
>        Left er -> print er
>        Right l -> writeFile target $ printSql l

================================================================================

getFnTables

read the operators and functions from the catalog of the given database
output four values: binops, prefixops, postfixops, functions
each is a list with type ({functionName} String
                         ,{args} [Type]
                         ,{retType} Type)

map cstring to pseudo
map types ending in [] to array types
map void to pseudo
map setof to setof type
remove any functions which have args or return type internal


> getFnTables :: [Char] -> IO ()
> getFnTables dbName = withConn ("dbname=" ++ dbName) $ \conn -> do
>    putStrLn "{"
>    let binopquery = "select oprname,\n\
>                     \       pg_catalog.format_type(oprleft, null),\n\
>                     \       pg_catalog.format_type(oprright, null),\n\
>                     \       pg_catalog.format_type(oprresult, null)\n\
>                     \  from pg_operator\n\
>                     \  where oprleft <> 0 and oprright <> 0\n\
>                     \  order by oprname;"
>    binopinfo <- selectRelation conn binopquery []
>    putStrLn $ makeVal "binaryOperatorTypes" $ map (show .convBinopRow) binopinfo
>    prefixopinfo <- selectRelation conn
>                      "select oprname,\n\
>                      \       pg_catalog.format_type(oprright, null),\n\
>                      \       pg_catalog.format_type(oprresult, null)\n\
>                      \  from pg_operator\n\
>                      \  where oprleft = 0\n\
>                      \  order by oprname;" []
>    putStrLn $ makeVal "prefixOperatorTypes" $ map (show . convUnopRow) prefixopinfo
>    postfixopinfo <- selectRelation conn
>                      "select oprname,\n\
>                      \       pg_catalog.format_type(oprleft, null),\n\
>                      \       pg_catalog.format_type(oprresult, null)\n\
>                      \  from pg_operator\n\
>                      \  where oprright = 0\n\
>                      \  order by oprname;" []
>    putStrLn $ makeVal "postfixOperatorTypes" $ map (show . convUnopRow) postfixopinfo
>    functionsinfo <- selectRelation conn
>                       "select p.proname,\n\
>                       \        pg_get_function_arguments(p.oid),\n\
>                       \        pg_get_function_result(p.oid) as ret\n\
>                       \  from pg_proc p\n\
>                       \  left join pg_catalog.pg_namespace n\n\
>                       \    on n.oid = p.pronamespace\n\
>                       \  where\n\
>                       \       pg_catalog.pg_function_is_visible(p.oid)\n\
>                       \       and not (p.proisagg\n\
>                       \                or p.proiswindow\n\
>                       \                or (p.prorettype =\n\
>                       \                'pg_catalog.trigger'::pg_catalog.regtype))\n\
>                       \  order by p.proname" []
>    putStrLn $ makeVal "functionTypes" $ map show $ filterOut $ map convFunctionRow functionsinfo
>    putStrLn "}"
>    where
>      filterOut =
>        filter
>          (\(_,args,ret) -> let ts = (ret:args)
>                            in case () of
>                              _ | length
>                                    (filter
>                                     (`elem`
>                                      (map ScalarType ["internal"
>                                                      ,"language_handler"
>                                                      ,"opaque"])) ts) > 0 -> False
>                                | otherwise -> True)
>      pArgString s = case parseArgString s of
>                       Left er -> error $ show er
>                       Right t -> t
>      pArg s = case parseArg s of
>                       Left er -> error $ show er
>                       Right t -> t
>      convFunctionRow l = (head l
>                          ,pArgString (l !! 1)
>                          ,pArg (l !! 2))
>      convBinopRow l = (head l
>                       ,toTypes (take 2 $ drop 1 l)
>                       ,pArg (l !! 3))
>      convUnopRow l = (head l
>                      ,[pArg (l !! 1)]
>                      ,pArg (l !! 2))

>      toTypes ss = map pArg ss
>      showFn :: (String, [Type], Type) -> String
>      showFn (s,ts,t) = "(" ++ stringIt s
>                        ++ ",[" ++ intercalate "," (map tToS ts) ++ "],"
>                        ++ tToS t ++ ")"
>      tToS :: Type -> String
>      tToS ty = case ty of
>               ScalarType t -> "ScalarType " ++ stringIt t
>               ArrayType t -> "ArrayType(" ++ tToS t ++ ")"
>               SetOfType t -> "SetOfType(" ++ tToS t ++ ")"
>               CompositeType _ _ -> "error"
>               DomainType _ _ -> "error"
>               Row _ -> "error"
>               TypeList _ -> "error"
>               p@(Pseudo _) -> show p
>               TypeError _ _ -> "error"
>               UnknownType  -> "error"
>      stringIt s = "\"" ++ replace "\"" "\\\"" s ++ "\""
>      makeVal nm rows = nm ++ " = [\n    "
>                        ++ intercalate ",\n    " rows
>                        ++ "\n    ]"

================================================================================

= getTypeStuff

will output type information and cast information

> getTypeStuff :: [Char] -> IO ()
> getTypeStuff dbName = withConn ("dbname=" ++ dbName) $ \conn -> do
>    putStrLn "{"
>    typeinfo <- selectRelation conn
>                  "with nonArrayTypeNames as\n\
>                  \(select\n\
>                  \   t.oid as typoid,\n\
>                  \   case typtype\n\
>                  \       when 'b' then\n\
>                  \         'ScalarType \"' || typname || '\"'\n\
>                  \       when 'c' then\n\
>                  \         'CompositeType \"' || typname || '\"'\n\
>                  \       when 'd' then\n\
>                  \         'DomainType \"' || typname || '\"'\n\
>                  \       when 'e' then\n\
>                  \         'EnumType \"' || typname || '\"'\n\
>                  \       when 'p' then 'Pseudo ' ||\n\
>                  \         case typname\n\
>                  \           when 'any' then 'Any'\n\
>                  \           when 'anyarray' then 'AnyArray'\n\
>                  \           when 'anyelement' then 'AnyElement'\n\
>                  \           when 'anyenum' then 'AnyEnum'\n\
>                  \           when 'anynonarray' then 'AnyNonArray'\n\
>                  \           when 'cstring' then 'Cstring'\n\
>                  \           when 'internal' then 'Internal'\n\
>                  \           when 'language_handler' then 'LanguageHandler'\n\
>                  \           when 'opaque' then 'Opaque'\n\
>                  \           when 'record' then 'Record'\n\
>                  \           when 'trigger' then 'Trigger'\n\
>                  \           when 'void' then 'Void'\n\
>                  \           else 'error pseudo ' || typname\n\
>                  \         end\n\
>                  \       else 'typtype error ' || typtype\n\
>                  \    end as descr\n\
>                  \  from pg_catalog.pg_type t\n\
>                  \  where pg_catalog.pg_type_is_visible(t.oid)\n\
>                  \        and not exists(select 1 from pg_catalog.pg_type el\n\
>                  \                       where el.typarray = t.oid)),\n\
>                  \arrayTypeNames as\n\
>                  \(select\n\
>                  \    e.oid as typoid,\n\
>                  \    'ArrayType (' ||\n\
>                  \    n.descr || ')' as descr\n\
>                  \  from pg_catalog.pg_type t\n\
>                  \  inner join pg_type e\n\
>                  \    on t.typarray = e.oid\n\
>                  \  left outer join nonArrayTypeNames n\n\
>                  \    on t.oid = n.typoid\n\
>                  \  where pg_catalog.pg_type_is_visible(t.oid))\n\
>                  \select descr from nonArrayTypeNames\n\
>                  \union\n\
>                  \select descr from arrayTypeNames\n\
>                  \order by descr;" []
>    putStr "defaultTypeNames = [\n    "
>    putStr $ intercalate ",\n    " $ map head typeinfo
>    putStrLn "]"
>    putStrLn "}"

> checkFnTypes :: IO ()
> checkFnTypes = mapM_ print checkFunctionTypes

================================================================================

> replace :: (Eq a) => [a] -> [a] -> [a] -> [a]
> replace _ _ [] = []
> replace old new xs@(y:ys) =
>   case stripPrefix old xs of
>     Nothing -> y : replace old new ys
>     Just ys' -> new ++ replace old new ys'


> split :: Char -> String -> [String]
> split _ ""                =  []
> split c s                 =  let (l, s') = break (== c) s
>                            in  l : case s' of
>                                            [] -> []
>                                            (_:s'') -> split c s''

> trim :: String -> String
> trim s = trimSWS $ reverse $ trimSWS $ reverse s
>        where
>          trimSWS :: String -> String
>          trimSWS = dropWhile (`elem` " \n\t")










select p.proname,
        pg_get_function_arguments(p.oid),
pg_get_function_result(p.oid) as ret
from pg_proc p
left join pg_catalog.pg_namespace n
on n.oid = p.pronamespace
where
pg_catalog.pg_function_is_visible(p.oid)
and not (p.proisagg
or p.proiswindow
or (p.prorettype =
'pg_catalog.trigger'::pg_catalog.regtype))
order by p.proname;

select
   case
       when typarray then 'ArrayType ('
       else ''
   end ||
   case typtype
       when 'b' then
         'ScalarType "' || typname || '"'
       when 'c' then
         'CompositeType "' || typname || '"'
       when 'd' then
         'DomainType "' || typname || '"'
       when 'e' then
         'EnumType "' || typname || '"'
       when 'p' then 'Pseudo ' ||
         case typname
           when '"any"' then 'Any'
           when 'anyarray' then 'AnyArray'
           when 'anyelement' then 'AnyElement'
           when 'anyenum' then 'AnyEnum'
           when 'anynonarray' then 'AnyNonArray'
           when 'cstring' then 'Cstring'
           when 'internal' then 'Internal'
           when 'language_handler' then 'LanguageHandler'
           when 'opaque' then 'Opaque'
           when 'record' then 'Record'
           when 'record[]' then 'RecordArray'
           when 'trigger' then 'Trigger'
           when 'void' then 'Void'
           else 'error pseudo ' || typname
         end
       else 'typtype error ' || typtyp
    end ||
    case
       when typarray then ')'
       else ''
    end as desc
  from pg_catalog.pg_type t
  where pg_catalog.pg_type_is_visible(t.oid)
  order by typtype, typcategory, typname;


select
   case typtype
       when 'b' then
         'ScalarType "' || typname || '"'
       when 'c' then
         'CompositeType "' || typname || '"'
       when 'd' then
         'DomainType "' || typname || '"'
       when 'e' then
         'EnumType "' || typname || '"'
       when 'p' then 'Pseudo ' ||
         case typname
           when 'any' then 'Any'
           when 'anyarray' then 'AnyArray'
           when 'anyelement' then 'AnyElement'
           when 'anyenum' then 'AnyEnum'
           when 'anynonarray' then 'AnyNonArray'
           when 'cstring' then 'Cstring'
           when 'internal' then 'Internal'
           when 'language_handler' then 'LanguageHandler'
           when 'opaque' then 'Opaque'
           when 'record' then 'Record'
           --when 'record[]' then 'RecordArray'
           when 'trigger' then 'Trigger'
           when 'void' then 'Void'
           else 'error pseudo ' || typname
         end
       else 'typtype error ' || typtype
    end as desc
  from pg_catalog.pg_type t
  where pg_catalog.pg_type_is_visible(t.oid)
        and not exists(select 1 from pg_catalog.pg_type el
                       where el.oid = t.typelem and el.typarray = t.oid)
  order by typtype, typcategory, typname;







select pg_catalog.format_type(t.oid, null) as name
  from pg_catalog.pg_type t
  where --pg_catalog.pg_type_is_visible(t.oid)
        typtype = 'p'
        --and not exists(select 1 from pg_catalog.pg_type el
        --               where el.oid = t.typelem and el.typarray = t.oid)
  order by typtype,typcategory,typispreferred desc,name;
