Copyright 2010 Jake Wheat

> -- | Functions to parse SQL.
> module Database.HsSqlPpp.Parser (
>              -- * Main
>               parseSql
>              ,parseSqlWithPosition
>              ,parseSqlFile
>              -- * Testing
>              ,parseExpression
>              ,parsePlpgsql
>              -- * errors
>              ,ParseErrorExtra(..)
>              )
>     where
> import Database.HsSqlPpp.Parsing.ParserInternal