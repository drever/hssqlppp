
> import System.Environment

> --import Language.Haskell.Exts
> --import Data.Generics.Uniplate.Data

> import Database.HsSqlPpp.Parse
> import GroomUtils
> import Text.Show.Pretty
> import qualified Data.Text.Lazy.IO as LT

> main :: IO ()
> main = do
>   [f] <- getArgs
>   src <- LT.readFile f
>   let ast = parseStatements defaultParseFlags
>                {pfDialect = SQLServer} f Nothing src
>   putStrLn $ either ppShow groomNoAnns ast
