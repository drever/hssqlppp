> {-# LANGUAGE OverloadedStrings #-}
> module Database.HsSqlPpp.Tests.TypeChecking.Aggregates
>     (aggregates) where

> import Database.HsSqlPpp.Tests.TestTypes
> import Database.HsSqlPpp.Types
> import Database.HsSqlPpp.Catalog
> import Database.HsSqlPpp.Dialect
> --import Database.HsSqlPpp.Internals.TypesInternal
> --import Database.HsSqlPpp.TypeChecker
> import Database.HsSqlPpp.Tests.TypeChecking.Utils
> --import Database.HsSqlPpp.Internals.TypesInternal hiding (mkTypeExtra,mkTypeExtraNN)

dodgy hack to support cube:
special case the cube

only support case where the group by consists of a single cube or
ordinary groups
no nested groups in the cube
type check
group by cube(a,b,...)
as if it was written
group by a,b,...

TODO: deal with types, null, rollup,cube, grouping sets, nested groups
and flexible combinations

> aggregates :: Item
> aggregates =
>   Group "aggregates"
>   [tcQueryExpr [CatCreateTable ("public","t") [("a", mkCatNameExtra "int4")
>                                  ,("b", mkCatNameExtra "int4")
>                                  ,("c", mkCatNameExtra "int4")]]
>    "select a,b,count(c) as c from t group by a,b"
>    $ Right $ CompositeType [("a", mkTypeExtra typeInt)
>                            ,("b", mkTypeExtra typeInt)
>                            ,("c", mkTypeExtraNN typeBigInt)]
>   ,tcQueryExpr [CatCreateTable ("public","t") [("a", mkCatNameExtra "int4")
>                                  ,("b", mkCatNameExtra "int4")
>                                  ,("c", mkCatNameExtra "int4")]]
>    "select a,b,count(c) as c from t group by cube(a,b)"
>    $ Right $ CompositeType [("a", mkTypeExtra typeInt)
>                            ,("b", mkTypeExtra typeInt)
>                            ,("c", mkTypeExtraNN typeBigInt)]
>   ]
>   where
>     tcQueryExpr cus =
>         let cat = makeCatalog postgresDialect cus
>         in TCQueryExpr cat defaultTypeCheckFlags {tcfDialect=postgresDialect}
>     typeInt = ScalarType "int4"
>     typeBigInt = ScalarType "int8"
