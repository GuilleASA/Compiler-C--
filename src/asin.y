/*****************************************************************************/
/**  Ejemplo de BISON-I: S E M - 2          jbenedi@dsic.upv.es>     V. 24  **/
/*****************************************************************************/
/** Nuestro código escrito en Flex (Guillem, David y Ruben)**/
%{
#include "libgci.h"
#include "header.h"
#include "libtds.h"
#include <string.h>

int cuenta_main = 0;
int mainSinParam = 0;

%}

%union {

       //int valor; /*valor para constante numérica, true, false (terminales)*/

       int desp; //Desplazamiento para guardar contextos locales
       int tipo; // El tipo de dato
       char *nombre; // Nombre de identificador (variable, función...)

       TIVAL tiVal; // Almacena el tipo y el valor de una constante (en ocasiones el valor es la posicion de memoria)
       REFES refes; // Almacenar las referencias (para los creaLans y completaLans)
       TIOP tiOp; // Almacena el tipo y el operador

       int refe; // Almacena la referencia a la TdD en parámetros de funciones.
       int op; // Almacena el operador de la expresion
}

%token <tiVal> CTE_ TRUE_ FALSE_ /*todos los token terminales con un valor asociado*/
%type <tiVal> const expre expreLogic expreSufi expreUna expreMul expreAd expreRel expreIgual expreOP
%token <tipo> INT_ BOOL_
%type <tipo> tipoSimp declaVar declaVarLocal inst listInst instIter instEntSal instExpre instSelec
%type <tiOp> opUna
%type <op> opAd opMul opRel opIgual opLogic
%token <nombre> ID_
%type <refe>  listParamAct paramAct /* Contienen la referencia para poder insertar la función en la TdS referenciando su TdD correspondiente */
%type <refes> paramForm listParaForm 
%token READ_ RETURN_ PRINT_ IF_ ELSE_ FOR_ MAS_ MENOS_
%token POR_ DIV_ OPAR_ CPAR_ OCOR_ CCOR_ OCUA_ CCUA_ PYC_ ASI_ COM_ AND_ OR_ EQ_  
%token NEQ_ NOT_ GTN_ LTN_ GET_ LET_

%type <refe> listDecla declaFunc decla

%%

programa :
       {
              //Inicializacion de variables globales
              niv = 0;
              dvar=0;
              cargaContexto(niv);
              si = 0;
              //Reserva espacio variables globales del programa, al acabar el programa dvar indica el espacio que ocuparán.
              $<refes>$.refe1 = creaLans(si);
              emite(INCTOP,crArgNul(),crArgNul(),crArgEnt(-1));
              //Emitir el salto al comienzo de la funcion main
              $<refes>$.refe2 = creaLans(si);
              emite(GOTOS, crArgNul(), crArgNul(),crArgEtq(-1));
       }
       listDecla
       {
              //Comprobar si el programa tiene main
              if(obtTdS("main").t == T_ERROR){
                     yyerror("El programa no tiene 'main'");
              }
              //Completar reserva espacio para variables globales
              completaLans($<refes>1.refe1,crArgEnt(dvar));
              //Completar salto al comienzo de la funcion main
              completaLans($<refes>1.refe2, crArgEtq($2));

              
       }
       ;
listDecla : decla { $$ = $1;}
       | listDecla decla {$$ = $2;}
       ;
       
decla  : declaVar {$$ = 0;}
       | declaFunc {$$ = $1;}   
       ;

declaVar : tipoSimp ID_ PYC_ 
       {
              if (!insTdS($2, VARIABLE, $1, niv, dvar,-1)) {
                     yyerror ("Identificador variable repetido");
                     $$ = T_ERROR;
              }else{
                     $$ = $1;
                     dvar += TALLA_TIPO_SIMPLE;
              }
       }
       | tipoSimp ID_ ASI_ const PYC_ 
       {      
              //Cambiamos para ponerlo por tipos
              /*if ($1 == T_LOGICO) {
                     if ($4 != TRUE && $4 != FALSE) {
                            yyerror("Tipo bool solo puede ser 0 o 1");
                     }
              }*/
             if ( !insTdS($2, VARIABLE, $1, niv, dvar, -1)) {
                     yyerror ("Identificador variable repetido");
                     $$ = T_ERROR;
              } else if ($1 != $4.ti){
                     yyerror("Error de tipos en la inicializacion de la variable");
                     $$ = T_ERROR;
              }else{
                     $$ = $1;
                     //Instruccion 3direcciones para la inicializacion de la variable
                     emite(EASIG, crArgEnt($4.val), crArgNul(), crArgPos(niv,dvar));
                     dvar += TALLA_TIPO_SIMPLE;
              }
              
       }
       | tipoSimp ID_ OCUA_ CTE_ CCUA_ PYC_       
       {
              int numelem = $4.val;
              if (numelem <= 0) {
                     yyerror("Talla inapropiada del array");
                     numelem = 0; // Esta mal, pero lo inserta como si bien para seguir encontrando mas errores
                     $$ = T_ERROR;
              }
              int refe = insTdA($1, numelem);
              if ( !insTdS($2, VARIABLE, T_ARRAY, niv, dvar, refe)){
                     yyerror ("Identificador del array repetido");
                     $$ = T_ERROR;
              } else{ $$ = $1; dvar += numelem * TALLA_TIPO_SIMPLE;} // dvar = proxima posicion de memoria vacia
       }     
       ;
const : CTE_ {$$ = $1;}
       | TRUE_ {$$ = $1;}
       | FALSE_ {$$ = $1;}
       ;
tipoSimp : INT_ {$$ = $1;}
       | BOOL_ {$$ = $1;}
       ;
declaFunc: tipoSimp ID_ 
              {      
                     /* Gestión del contexto y guardar dvar */
                     // Pág. 11 de enunciado está el esquema:
                     $<refes>$.refe1 = dvar; //Esto es el desplazamiento
                     $<refes>$.refe2 = -1;
                     if (strcmp($2, "main") == 0) {
                            $<refes>$.refe2 = si;
                     }
                     
                     dvar = - TALLA_TIPO_SIMPLE - TALLA_SEGENLACES; // Inicializo dvar para las variables locales de la funcion
                     niv++; 
                     cargaContexto(niv);
              }
              OPAR_ paramForm CPAR_ 
              {
                     dvar = 0; // Inicializo dvar para las variables locales de la funcion
                     /* Insertar información de la función en la TdS */
                     // En paramForm ($5) se almacena la referencia a la TdD
                     //if ( !insTdS($2, FUNCION, $1, niv-1, $<refes>3.refe1, $5.refe1)) { // $5 contiene la referencia a la TdD
                     if ( !insTdS($2, FUNCION, $1, niv-1, si, $5.refe1)) { // $5 contiene la referencia a la TdD
                            yyerror ("Identificador de funcion repetido");
                     }

                     //revisar si la talla es tiposimple
                     //else dvar += TALLA_TIPO_SIMPLE;
                     INF inf = obtTdD($5.refe1);
                     if (strcmp($2, "main") == 0 && inf.tsp == -1) {
                            mainSinParam = 1;
                     }
                     
              }
              bloque 
              {
                     
                     /* Gestión del contexto y recuperar dvar */
                     descargaContexto(niv);
                     niv--;
                     dvar = $<refes>3.refe1;

                     if (strcmp($2, "main") == 0) {
                            $$ = $<refes>3.refe2;
                            // Creo la referencia de salto al main
                            cuenta_main++;
                            if (cuenta_main > 1) {
                                   yyerror("El programa tiene mas de un 'main'");
                            }
                            /******* Emite FIN si es ‘‘main’’ y RETURN si no lo es */
                            //Si es main tiene que hacer FIN
                            emite(FIN, crArgNul(), crArgNul(), crArgNul());
                     }else{
                            //Si no es main tiene que hacer RET
                            emite(RET, crArgNul(), crArgNul(), crArgNul());
                     }
              }
       ;
paramForm : 
       {
              // Si no tiene parámetros
              $$.refe1 = insTdD(-1, T_VACIO);
              // insTdD calcula sobre la marcha el número de parámetros.
       }
       | listParaForm 
       {
              $$ = $1;
       }
       ;
listParaForm : tipoSimp ID_ 
       {
              // Lo mismo que cuando se declaraban variables en producción declaVar
              if (!insTdS($2, PARAMETRO, $1, niv, dvar, -1)) { // Es un parámetro (categoría: parámetro) y su tipo es simple ($1: entero o bool)
                     yyerror ("Identificador de parametro repetido");
              }
              else{
                     dvar -= TALLA_TIPO_SIMPLE;
              }
       
              // Estamos declarando la función, no se hace nada de 3 direcciones:
              //Recuperamos de la pila el valor que ha introducido la funcion que nos llama
              //$$.refe2 = creaVarTemp();
              //emite(EASIG, crArgPos(niv,dvar), crArgNul(), crArgPos(niv,$$.refe2));

              //El ultimo paramemtro es el primero que se ejecuta
              $$.refe1 = insTdD(-1, $1); // Esto crea la referencia a la TdD.
              
       }
       | tipoSimp ID_ COM_ listParaForm
       {
              if (!insTdS($2, PARAMETRO, $1, niv, dvar, -1)) {
                     yyerror ("Identificador de parametro repetido");
              }
              else{
                     dvar -= TALLA_TIPO_SIMPLE;
              }

              //Recuperamos de la pila el valor que ha introducido la funcion que nos llama
              //$$.refe2 = creaVarTemp();
              //emite(EASIG, crArgPos(niv,dvar), crArgNul(), crArgPos(niv,$$.refe2));
              $$.refe1 = insTdD($4.refe1, $1); // Como ya tengo la referencia creada, la uso.

       }
       ;
bloque : 
       {
              //Instrucciones 3direcciones para una funcion llamada
              /******* Cargar los enlaces de control */
              emite(PUSHFP, crArgNul(), crArgNul(), crArgNul());
              emite(FPTOP, crArgNul(), crArgNul(), crArgNul());
              /******* Reserva de espacio para variables locales y temporales */
              $<refe>$ = creaLans(si);
              emite(INCTOP, crArgNul(), crArgNul(), crArgEnt(-1));
       }
       OCOR_ declaVarLocal listInst RETURN_ expre 
       {
              
              if (mainSinParam == 1 && ($3 == T_ERROR || $4 == T_ERROR || $6.ti == T_ERROR)) yyerror("En la declaracion de la funcion [1]");
              else{
                     INF inf = obtTdD(-1);
                     if (inf.tipo != T_ERROR && $6.ti != inf.tipo ) yyerror("Error de tipos en el 'return'");
                     /******* Completa reserva espacio para variables locales y temporales */
                     completaLans($<refe>1, crArgEnt(dvar));
                     /******* Guardar valor de retorno */
                     int desplValRet = inf.tsp + TALLA_TIPO_SIMPLE + TALLA_SEGENLACES;
                     emite(EASIG, crArgPos(niv,$6.val), crArgNul(), crArgPos(niv,-desplValRet));
                     /******* Libera el segmento de variables locales y temporales */
                     /******* Descarga de los enlaces de control */
                     emite(TOPFP, crArgNul(), crArgNul(), crArgNul());
                     emite(FPPOP, crArgNul(), crArgNul(), crArgNul());
                     /******* Mostrar la informacion de la funcion en la TdS */
                     if (verTdS) {
                            printf("Mostramos la TdS tras procesar función %s\n", inf.nom);
                            mostrarTdS();
                     }
              }
              
       } PYC_ CCOR_
       ;
declaVarLocal: { $$ = T_VACIO;}
       | declaVarLocal declaVar {
              $$ = T_ERROR;
              if ($1 != T_ERROR && $2 != T_ERROR) {$$ = $2;}
       }
       ;
listInst: { $$ = T_VACIO;}
       | listInst inst {
              $$ = T_ERROR;
              if ($1 != T_ERROR && $2 != T_ERROR) {$$ = $2;}
       }
       ;
inst: OCOR_ listInst CCOR_ {$$ = $2;}
       | instExpre {$$ = $1;}
       | instEntSal {$$ = $1;}
       | instSelec {$$ = $1;}
       | instIter {$$ = $1;}
       ;
instExpre: expre PYC_ { $$ = $1.ti;}
       | PYC_ { $$ = T_VACIO;}
       ;
instEntSal: READ_ OPAR_ ID_ CPAR_ PYC_
       {
              SIMB sim = obtTdS($3);
              if (sim.t == T_ERROR){ yyerror("Objeto no declarado"); $$ = T_ERROR;}
              else if (sim.t != T_ENTERO){yyerror("El argumento del 'read' debe ser 'entero'"); $$ = T_ERROR;}
              
              emite(EREAD, crArgNul(), crArgNul(), crArgPos(sim.n,sim.d)); // Valor leído a la variable ID_
       }
       | PRINT_ OPAR_ expre CPAR_ PYC_
       {
              if ($3.ti != T_ENTERO){ yyerror("La expresion del 'print' debe ser 'entera'"); $$ = T_ERROR;}

              emite(EWRITE,crArgNul(),crArgNul(),crArgPos(niv,$3.val));
       }
       ;
instSelec: IF_ OPAR_ expre 
       {
              if ($3.ti != T_LOGICO && $3.ti != T_ERROR){
                     yyerror("La expresion del 'if' debe ser 'logico'");
                     $<tiVal>$.ti = T_ERROR;
              }else{
                     $<tiVal>$.ti = T_VACIO;
              }
              //Referemcia para cuando sea falso (directamente al else)
              $<tiVal>$.val = creaLans(si);
              emite(EIGUAL, crArgPos(niv,$3.val), crArgEnt(0), crArgEnt(-1));

       } CPAR_ inst
       {
              //Referencia para cuando sea verdadero tienes que terminar (no entra en el else)
              $<refe>$ = creaLans(si);
              emite(GOTOS, crArgNul(), crArgNul(), crArgEnt(-1));

              //Completar la referencia de cuando sea falso (else)
              completaLans($<tiVal>4.val, crArgEtq(si));
       } 
       ELSE_ inst
       {
              if ($3.ti == T_ERROR || $6 == T_ERROR || $9 == T_ERROR){
                     $$ = T_ERROR;
              }else{
                     completaLans($<refe>7, crArgEtq(si)); // Tras else, fuera del if
                     $$ = $<tiVal>4.ti;
              }
       }
       ;
instIter: FOR_ OPAR_ expreOP
       {
              //Referencia de la siguiente es la comparacion (guarda del bucle)
              $<refe>$ = si;
       }
       PYC_ expre
       {
              //Referencia para que cuando la condicion sea falsa salgas
              $<refes>$.refe1 = creaLans(si);
              //Si es falso te vas al final del for, referencia de arriba
              emite(EIGUAL, crArgPos(niv,$6.val), crArgEnt(0), crArgEnt(-1));

              //Referencia para irte al cuerpo del for
              $<refes>$.refe2 = creaLans(si);
              //Si es verdadero te vas al cuerpo, referencia de arriba
              emite(GOTOS, crArgNul(), crArgNul(), crArgEnt(-1));

              //Referencia de incremento para la siguiente iteración
              $<refes>$.refe3 = si;
       } 
       PYC_ expreOP 
       {
              if ($3.ti != T_ENTERO && $3.ti != T_LOGICO && $3.ti != T_VACIO ){
                     yyerror("La 'expreOp' del 'for' debe ser de tipo simple");
                     $<tipo>$ = T_ERROR;
              } else if ($9.ti != T_ENTERO && $9.ti != T_LOGICO && $9.ti != T_VACIO ){
                     yyerror("La 'expreOp' del 'for' debe ser de tipo simple");
                     $<tipo>$ = T_ERROR;
              } else if ($6.ti != T_LOGICO){
                     yyerror("La expresion del 'for' debe ser 'logica'");
                     $<tipo>$ = T_ERROR;
              }

              // Tras el incremente vas a comprobar la guarda del bucle
              emite(GOTOS, crArgNul(), crArgNul(), crArgEtq($<refe>4));

              // Completar la referencia de cuando la condicion sea verdadera
              completaLans($<refes>7.refe2, crArgEtq(si));
       }
       CPAR_ inst
       {
              if ($3.ti == T_ERROR || $6.ti == T_ERROR || $9.ti == T_ERROR || $12 == T_ERROR){
                     $$ = T_ERROR;
              }else{
                     $$ = $<tipo>$;
              }

              // Tras la iteración, vas al incremento
              emite(GOTOS, crArgNul(), crArgNul(), crArgEtq($<refes>7.refe3));

              // Completar la referencia de cuando la condicion sea falsa
              completaLans($<refes>7.refe1, crArgEtq(si));
       }
       ;
expreOP: {$$.ti = T_VACIO;}
       | expre { $$ = $1;}
       ;
expre: expreLogic
       {
              $$ = $1; //Aqui es donde le llega el tipo entero o logico
       }
       | ID_ ASI_ expre
       {
              SIMB sim = obtTdS($1);
              $$.ti = T_ERROR;
              if (sim.t == T_ERROR){
                     yyerror("Objeto no declarado");
              }
              else if (sim.t != T_ARRAY && $3.ti == T_ARRAY && $3.ti != T_ERROR){
                     yyerror("La variable debe ser de tipo simple");
              } else if (!(((sim.t == T_ENTERO) && ($3.ti == T_ENTERO)) || ((sim.t == T_LOGICO) && ($3.ti == T_LOGICO))) && $3.ti != T_ERROR){
                     yyerror("Error de tipos en la 'asignacion'"); 
              }else{
                     $$ = $3;
                     emite(EASIG, crArgPos(niv,$3.val), crArgNul(), crArgPos(niv,sim.d)); // Valor de expre se asigna a ID_
              }
              /*AVISO PDF: Advertid que para evitar una secuencia de errores redundantes debería modificarse este
codigo para que solo se de un nuevo mensaje de error si el error se produce en esta regla,
y no, si proviene de errores anteriores a trav´es de $1 o $3.*/
       }
       | ID_ OCUA_ expre CCUA_ ASI_ expre
       {

              $$.ti = T_ERROR; // Se pone por defecto, si sale bien se cambia
              SIMB sim = obtTdS($1);
              if (sim.t == T_ERROR){
                     yyerror("Objeto no declarado");

              } else if (sim.t != T_ARRAY){
                     yyerror("La variable debe de ser de tipo 'array'");

              } else if ($3.ti != T_ENTERO && $3.ti != T_ERROR){
                     yyerror("El indice del 'array' debe ser entero");
              }
              //Quiza faltaria comprobar que no te salgas del array, seguramente no , porque se deja al usuario
              else{
                     DIM dim = obtTdA(sim.ref);
                     if ($6.ti != dim.telem && $6.ti != T_ERROR){
                            yyerror("Error de tipos en la asignacion a un 'array'");
                     }else{
                            $$.ti = dim.telem;
                            emite(EVA,crArgPos(sim.n,sim.d),crArgPos(niv,$3.val),crArgPos(niv,$6.val)); // ID_[expre1] = expre2
                     }
              }
              
       }
       ;
expreLogic: expreIgual {$$ = $1;}
       | expreLogic opLogic expreLogic
       {
              if ($1.ti != T_LOGICO || $3.ti != T_LOGICO){
                     yyerror("Error en 'expresión lógica'");
                     $$.ti = T_ERROR; 
              }else{
                     $$.ti = T_LOGICO;
              }

              $$.val = creaVarTemp();
              if ($2 == 40){ // AND
                     emite(EMULT, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgPos(niv,$$.val));
              }else{ // OR
                     emite(ESUM, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgPos(niv,$$.val));
                     emite(EMENEQ, crArgPos(niv,$$.val), crArgEnt(1), crArgEtq(si+2)); // Por si la suma da 2 (true o false son 1 o 0)
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val)); // Si suma es 2 se pone a 1 -> true
              }
              
              
       }
       ;
expreIgual: expreRel { $$ = $1;}
       | expreIgual opIgual expreRel
       {
              //Los tipos pueden ser enteros o logicos, pero tienen que ser ambos del mismo tipo
              if ($1.ti != $3.ti){
                     yyerror("Error en 'expresión de igualdad'");
                     $$.ti = T_ERROR;
              }else{
                     $$.ti = T_LOGICO; // Siempre devuelve un valor logico
              }

              $$.val = creaVarTemp();
              if($2 == EIGUAL){ // Operacion ==
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val)); // Asumimos verdadero
                     emite(EIGUAL, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val)); // Si no, lo cambiamos a falso
              }else{ // Operacion !=
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
                     emite(EDIST, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));
              }

       }
       ;
expreRel: expreAd {$$ = $1;}
       | expreRel opRel expreAd
       {
              //Ambos tienen que ser enteros
              if ($1.ti != T_ENTERO || $3.ti != T_ENTERO) {
                     yyerror("Error en 'expresión de relacional'");
                     $$.ti = T_ERROR;
              }else{
                     $$.ti = T_LOGICO; // Siempre devuelve un valor logico
              }
              $$.val = creaVarTemp();

              emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
              emite($2, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
              emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));

              /* Es lo mismo que lo de arriba
              if ($2 == EMAY){//Operacion >
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
                     emite($2, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));     
              }else if ($2 == EMEN){ //Operacion <
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
                     emite(EMEN, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));

              }else if ($2 == EMAYEQ){ //Operacion >=
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
                     emite(EMAYEQ, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));
              }else if ($2 == EMENEQ){ //Operacion <=
                     emite(EASIG,crArgEnt(1),crArgNul(),crArgPos(niv,$$.val));
                     emite(EMENEQ, crArgPos(niv,$1.val), crArgPos(niv,$3.val), crArgEtq(si+2));
                     emite(EASIG,crArgEnt(0),crArgNul(),crArgPos(niv,$$.val));

              }*/
       }
       ;
expreAd: expreMul {$$ = $1;}
       | expreAd opAd expreMul
       {
              //Ambos tienen que ser enteros
              if ($1.ti != T_ENTERO || $3.ti != T_ENTERO){
                     yyerror("Error de tipos en 'expresion aditiva'");
                     $$.ti = T_ERROR;
              }else{
                     $$.ti = T_ENTERO;
              } // Siempre devuelve un valor entero

              $$.val = creaVarTemp();
              emite($2,crArgPos(niv,$1.val),crArgPos(niv,$3.val),crArgPos(niv,$$.val));
       }
       ;
expreMul: expreUna {$$ = $1;}
       | expreMul opMul expreUna
       {
              //Ambos tienen que ser enteros
              if ($1.ti != T_ENTERO || $3.ti != T_ENTERO){
                     yyerror("Error de tipos en 'expresion multiplicativa'");
                     $$.ti = T_ERROR;
              }else{
                     $$.ti = T_ENTERO; // Siempre devuelve un valor entero
              }

              $$.val = creaVarTemp();
              emite($2,crArgPos(niv,$1.val),crArgPos(niv,$3.val),crArgPos(niv,$$.val));
       }
       ;
expreUna: expreSufi {$$ = $1;}
       | opUna expreUna
       {
              if($1.ti != $2.ti){
                     yyerror("Error en 'expresión unaria'");
                     $$.ti = T_ERROR;
              }else{
                     $$.ti = $1.ti;
              }

              $$.val = creaVarTemp();
              if ($1.op == EDIF){ // Operacion: -numero
                     emite(ESIG, crArgPos(niv,$2.val), crArgNul(), crArgPos(niv,$$.val)); // Cambio de signo

              }else if ($1.op == ESIG){ // Operacion: not
                     emite(EDIF,crArgEnt(1),crArgPos(niv,$2.val),crArgPos(niv,$$.val)); // true -> false, false -> true

              }else{ // Operacion: +numero
                     emite(EASIG,crArgPos(niv,$2.val),crArgNul(),crArgPos(niv,$$.val)); // Se queda igual
              }
              
       }
       ;
expreSufi: const 
       {
              $$.ti = $1.ti;
              $$.val = creaVarTemp();
              emite(EASIG, crArgEnt($1.val), crArgNul(), crArgPos(niv,$$.val));
       }
       | OPAR_ expre CPAR_ {$$ = $2;}
       | ID_ 
       {
              SIMB sim = obtTdS($1);
              if (sim.t == T_ERROR){
                     yyerror("Objeto no declarado");
                     $$.ti = T_ERROR;
              }
              else{
                     $$.ti = sim.t;
                     $$.val = creaVarTemp();
                     emite(EASIG, crArgPos(sim.n,sim.d), crArgNul(), crArgPos(niv,$$.val)); // Leemos el contenido de ID_ a una variable temporal
              }
       }
       | ID_ OCUA_ expre CCUA_
       {
              $$.ti = T_ERROR; // Se pone por defecto, si sale bien se cambia
              SIMB sim = obtTdS($1);
              if (sim.t == T_ERROR){
                     yyerror("Objeto no declarado");
              }else if (sim.t != T_ARRAY){
                     yyerror("La variable debe de ser de tipo 'array'");
              }else if ($3.ti != T_ENTERO){
                     yyerror("El indice del 'array' debe ser entero");
              }
              //Quiza faltaria comprobar que no te salgas del array, seguramente no , porque se deja al usuario
              else{
                     DIM dim = obtTdA(sim.ref);
                     $$.ti = dim.telem;

                     $$.val = creaVarTemp();
                     emite(EAV,crArgPos(sim.n,sim.d),crArgPos(niv,$3.val),crArgPos(niv,$$.val)); // varTemp = ID_[expre]
              }
       }
       | ID_
       {
              /********************* Reservar espacio para el valor de retorno */
              emite(EPUSH,crArgNul(),crArgNul(),crArgEnt(0));
       }
       OPAR_ paramAct CPAR_
       {
              /*$$ = obtTdS($1).t;//Sera el tipo que devuelve la funcion
              descargaContexto(niv);
              niv--;
              dvar = $<desp>2;*/

              $$.ti = T_ERROR; // Se pone por defecto, si sale bien se cambia

              SIMB sim = obtTdS($1);
              if (sim.t != T_ERROR){

                     INF func = obtTdD(sim.ref);
                     if (func.tipo == T_ERROR){ yyerror("Error de tipos en la 'expresión de llamada a función'");}
                     //Hacemos la comprobacion el dominio de la funcion original y el ficticio
                     else if (!cmpDom(sim.ref,$4)){ yyerror("En el dominio de los parametros actuales");}
                     else {$$.ti = func.tipo;}
                     
                     //Codigo en 3d para la funcion llamadora
                     /************************** Llamada a la funcion */
                     emite(CALL,crArgNul(),crArgNul(),crArgEtq(sim.d));//Apila la dir de retorno y llama a la funcion
                     //En caso de que la funcion devuelva otro tipo distinto, seria necesario comprobar la talla, para pasarla al emite
                     /************************** Desapilar el segmento de parametros */
                     emite(DECTOP,crArgNul(),crArgNul(),crArgEnt(func.tsp));
                     /************************** Desapilar y asignar el valor de retorno */
                     $$.val = creaVarTemp();
                     emite(EPOP,crArgNul(),crArgNul(),crArgPos(niv,$$.val));

              }else{
                     yyerror("Objeto no declarado");
              }

              

       }
       ;
//Creamos un dominio nuevo ficticio para comprobar que los parametros son correctos
paramAct: 
       {
              // Si no tiene parámetros
              $$ = insTdD(-1, T_VACIO);
              // insTdD calcula sobre la marcha el número de parámetros.
       }
       | listParamAct
       {
              //Comprobar que el numero de parametros sea el mismo
              //Comprobar que todos los parametros existe y que son del tipo correcto
              $$ = $1;

       }
       ;
listParamAct: expre
       {
              emite(EPUSH,crArgNul(),crArgNul(),crArgPos(niv,$1.val)); // Apilamos los parámetros uno a uno
              $$ = insTdD(-1, $1.ti);
       }
       | expre
       {
              emite(EPUSH,crArgNul(),crArgNul(),crArgPos(niv,$1.val)); // Apilamos los parámetros uno a uno
       }
       COM_ listParamAct
       {
              $$ = insTdD($4, $1.ti);
       }
       ;
opLogic: AND_ {$$ = 40;} //Inidicadores de AND y OR
       | OR_ { $$ = 50;}
       ;
opIgual: EQ_ {$$ = EIGUAL;} // Estas operaciones son indicaciones para despues, habra que simularlas, ya que estas son para saltos
       | NEQ_ {$$ = EDIST;}
       ;
opRel: GTN_ {$$ = EMAY;}
       | LTN_ {$$ = EMEN;}
       | GET_ {$$ = EMAYEQ;}
       | LET_ {$$ = EMENEQ;}
       ;
opAd: MAS_ { $$ = ESUM;}
       | MENOS_ {$$ = EDIF;}
       ;
opMul: POR_ { $$ = EMULT;}
       | DIV_ {$$ = EDIVI;}
       ;
opUna: MAS_ 
       {
              $$.ti = T_ENTERO;
              $$.op = ESUM;
       }
       | MENOS_
       {
              $$.ti = T_ENTERO;
              $$.op = EDIF;
       }
       | NOT_
       {
              $$.ti = T_LOGICO;
              $$.op = ESIG;
       }
       ;

%%
