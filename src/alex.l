/** Nuestro código escrito en Flex (Guillem, David y Ruben)**/

%{
#include <stdio.h>
#include "header.h"
#include "asin.h"
#include "libtds.h" // Para usar las varibales globales 

#define  retornar(x) {if (verbosidad) ECHO; return x;}

%}
/*----------------------------------------------------------------------
  Dado que las funciones "input()" y "unput(c)" son costosas y no las
  utilizaremos, evitaremos que se generen automaticamente sus rutinas
  correspondientes desactivandolas mediante las siguientes opciones:
----------------------------------------------------------------------*/
%option noinput
%option nounput
/*----------------------------------------------------------------------
  Para mantener el numero de linea actual en la variable global yylineno
----------------------------------------------------------------------*/
%option yylineno

delimitador     [ \t\n]+
digito          [0-9]
entero          {digito}+
variable        [a-zA-Z][a-zA-Z0-9_]* 
real            {digito}+\.{digito}*|{digito}*\.{digito}+
comentario      "//".*
int             "int"
bool            "bool"
true            "true"
false           "false"
read            "read"
return          "return"
print           "print"
if              "if"
else            "else"
for             "for"
and             "&&"
or              "||"
eq              "=="
neq             "!="
not             "!"
gtn             ">"
ltn             "<"
get             ">="
let             "<="

%%

{delimitador}   {if (verbosidad) ECHO ; }
{comentario}    {if (verbosidad) ECHO ; }
{int}           { yylval.tipo = T_ENTERO; retornar (INT_) ; }
{bool}          { yylval.tipo = T_LOGICO; retornar (BOOL_) ; }
{true}          { yylval.tiVal.val = TRUE; yylval.tiVal.ti = T_LOGICO; retornar (TRUE_) ; }
{false}         { yylval.tiVal.val = FALSE; yylval.tiVal.ti = T_LOGICO; retornar (FALSE_) ; }
{read}          { retornar (READ_) ; }
{return}        { retornar (RETURN_) ; }
{print}         { retornar (PRINT_) ; }
{if}            { retornar (IF_) ; }
{else}          { retornar (ELSE_) ; }
{for}           { retornar (FOR_) ; }
"+"		 		      { retornar (MAS_) ; }
"-"             { retornar (MENOS_) ; }
"*"             { retornar (POR_) ; }
"/"             { retornar (DIV_) ; }
"("             { retornar (OPAR_) ; }
")"             { retornar (CPAR_) ; }
"{"             { retornar (OCOR_) ; }
"}"             { retornar (CCOR_) ; }
"["             { retornar (OCUA_) ;}
"]"             { retornar (CCUA_) ;}
";"             { retornar (PYC_) ; }
"="             { retornar (ASI_) ; }
","             { retornar (COM_) ; }
{and}           { retornar (AND_) ; }
{or}            { retornar (OR_) ; }
{eq}            { retornar (EQ_) ; }
{neq}           { retornar (NEQ_) ; }
{not}           { retornar (NOT_) ; }
{gtn}           { retornar (GTN_) ; }
{ltn}           { retornar (LTN_) ; }
{get}           { retornar (GET_) ; }
{let}           { retornar (LET_) ; }
{real}          { yylval.tiVal.val = atoi(yytext); yylval.tiVal.ti = T_ENTERO; retornar (CTE_) ; }
{entero}        { yylval.tiVal.val = atoi(yytext); yylval.tiVal.ti = T_ENTERO; retornar (CTE_) ; }
{variable}      { yylval.nombre = strdup(yytext); retornar (ID_) ; }
.				        { yyerror("Caracter desconocido") ;}


%%


