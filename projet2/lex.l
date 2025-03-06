%{
#include "y.tab.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

%}


%%
[ \t\n]+            ;

"int"               return DECINT;
"if"                return IF;
"else"              return ELSE;
"while"             return WHILE;
"printf"            return PRINTF;

"("                 return OP;
")"                 return CP;
"{"                 return OB;
"}"                 return CB;
"="                 return EGALE;
";"                 return PV;

"=="                { yylval.num = 0; return COMP; }
"!="                { yylval.num = 1; return COMP; }
"<="                { yylval.num = 4; return COMP; }
">="                { yylval.num = 5; return COMP; }
"<"                 { yylval.num = 2; return COMP; }
">"                 { yylval.num = 3; return COMP; }

"+"               return PLUS;
"-"                 return MOINS;
"*"               return MULT;
"/"                 return DIV;

[0-9]+              {
    yylval.num = atoi(yytext);
    return INT;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.id = strdup(yytext);
    return IDENT;
}

.                   {
    fprintf(stderr, "词法错误: 无法识别字符 '%s'. 程序中止。\n", yytext);
    exit(1);
}

%%

int yywrap() {
    return 1;
}
