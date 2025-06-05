/*****************************************************************************/
/**   Ejemplo de un posible fichero de cabeceras donde situar las           **/
/** definiciones de constantes, variables y estructuras para MenosC. Los    **/
/** alumnos deberan adaptarlo al desarrollo de su propio compilador.    **/
/*****************************************************************************/
#ifndef _HEADER_H
#define _HEADER_H

#include <stdio.h>
/****************************************************** Constantes generales */
#define TRUE  1
#define FALSE 0

#define TALLA_TIPO_SIMPLE 1 // Talla de los tipos simples, entero y logico
#define TALLA_SEGENLACES 2 // Talla del segmento de Enlaces de Control
/************************************* Variables externas definidas en el AL */
extern int yylex();
extern int yyparse();

extern FILE *yyin;                           /* Fichero de entrada           */
extern int   yylineno;                       /* Contador del numero de linea */
extern char *yytext;                         /* Patron detectado             */
/********* Funciones y variables externas definidas en el Programa Principal */
extern void yyerror(const char * msg) ;   /* Tratamiento de errores          */

extern int verbosidad;                   /* Flag si se desea una traza       */
extern int numErrores;              /* Contador del numero de errores        */
extern int verTdS;                  // Para mostrar la TdS

typedef struct tiVal /******************************** Estructura para guardar tipo y valor de const */
       {
              int   ti;               /* Tipo del objeto*/
              int   val;               /* Valor del objeto*/
       } TIVAL;

typedef struct refes /******************************** Estructura para guardar referencias */
       {
              int   refe1;               /* */
              int   refe2;               /* */
              int   refe3;
       } REFES;

typedef struct tiOp /******************************** Estructura para guardar referencias */
       {
              int   ti;               /* */
              int   op;               /* */
       } TIOP;
#endif  /* _HEADER_H */
/*****************************************************************************/
