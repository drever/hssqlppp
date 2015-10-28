> module Database.HsSqlPpp.Tests.TestTypes (
>     defaultParseFlags
>    ,defaultTypeCheckFlags
>    ,Dialect(..)
>    ,ParseFlags(..)
>    ,TypeCheckFlags(..)
>    ,Item(..)
>    ,defaultTemplate1Catalog
>    ,emptyEnvironment
>    ,updateCatalog
>   ) where

> import Database.HsSqlPpp.Syntax
> import Database.HsSqlPpp.LexicalSyntax (Token)
> import Database.HsSqlPpp.Annotation
> import qualified Data.Text as T
> --import Data.Text (Text)
> import qualified Data.Text.Lazy as L
> --import Control.Arrow
> --import Test.HUnit
> --import Test.Framework.Providers.HUnit
> --import Test.Framework
> --import Data.List
> --import Data.Generics.Uniplate.Data
> import Database.HsSqlPpp.Parse
> import Database.HsSqlPpp.TypeCheck
> --import Database.HsSqlPpp.Annotation
> import Database.HsSqlPpp.Catalog
> --import Database.HsSqlPpp.Ast hiding (App)
> import Database.HsSqlPpp.Types
> --import Database.HsSqlPpp.Pretty
> --import Database.HsSqlPpp.Utility
> --import Database.HsSqlPpp.Internals.TypeChecking.Environment
> --import Text.Show.Pretty
> --import Debug.Trace
> --import Database.HsSqlPpp.Tests.TestUtils
> --import Control.Monad

> --import Database.HsSqlPpp.Utils.GroomUtils
> --import qualified Data.Text.Lazy as L
> import Database.HsSqlPpp.Internals.TypeChecking.TypeConversion.TypeConversion2

> data Item = Group String [Item]
>           | ParseScalarExpr ParseFlags L.Text ScalarExpr
>           | ParseStmts ParseFlags L.Text [Statement]
>           | ParseProcSql ParseFlags L.Text [Statement]
>           | ParseQueryExpr ParseFlags L.Text QueryExpr
>           | Lex Dialect T.Text [Token]
>           | TCScalExpr Catalog Environment TypeCheckFlags
>                        L.Text (Either [TypeError] Type)
>           | TCQueryExpr Catalog TypeCheckFlags
>                         L.Text (Either [TypeError] Type)
>           | TCStatements Catalog TypeCheckFlags
>                          L.Text (Maybe [TypeError])
>           | InsertQueryExpr [CatalogUpdate] L.Text (Either [TypeError] Type)
>           | RewriteQueryExpr TypeCheckFlags [CatalogUpdate] L.Text L.Text

>           | ImpCastsScalar TypeCheckFlags L.Text L.Text
>           | ScalarExprExtra Catalog Environment L.Text (Either [TypeError] TypeExtra)
>           | MatchApp Dialect Catalog [NameComponent]
>                      [(TypeExtra, Maybe LitArg)]
>                      (Either [TypeError] ([TypeExtra],TypeExtra))
