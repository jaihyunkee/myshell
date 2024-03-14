
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <stdio.h>
#include <string.h>
#include <regex.h>
#include <dirent.h>
#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE PIPE AMPERSAND GREATGREAT LESS GREATAMPERSAND GREATGREATAMPERSAND TWOGREAT

%{
//#define yylex yylex
#include <cstdio>
#include <regex>
#include "shell.hh"

void yyerror(const char * s);
int yylex();

int cmpfunc (const void * a, const void * b);
void expandWildcardsIfNecessary(std::string *arg);
void expandWildcard(char * prefix, char * suffix);
int cmpfunc(const void *a, const void *b);
%}




%%
goal: command_list;

command_list :
  command_line |
  command_list command_line
  ;/* command loop*/


command_line:
  pipe_list io_modifier_list background_optional NEWLINE {
    Shell::_currentCommand.execute();
  }
  | NEWLINE {
    Shell::prompt();
  }
  | error NEWLINE{yyerrok;}
  ; /*error recovery*/

pipe_list:
    cmd_and_args
    | pipe_list PIPE cmd_and_args
    ;

cmd_and_args:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str()); 
    if(!strcmp($1->c_str(), "exit")){
      exit(1);
    }
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
    Shell::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
  }
  arg_list
  ;

arg_list:
  arg_list argument
  | /*empty string*/
;

argument:
  WORD {
    expandWildcardsIfNecessary($1);
  }
  ;

io_modifier_list:
  io_modifier_list io_modifier
  | io_modifier
  | /*empty*/
  ;

io_modifier:
  GREATGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (  !Shell::_currentCommand._outFile  ){
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._append = true;
    }
    else {
      fprintf(stderr ,"Ambiguous output redirect.\n");
    }
  }
  | GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    
    if (  !Shell::_currentCommand._outFile  ){
      Shell::_currentCommand._outFile = $2;
    }
    else {
      fprintf(stderr , "Ambiguous output redirect.\n");
    }
  }
  | GREATGREATAMPERSAND WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());

    if (  !Shell::_currentCommand._outFile & !Shell::_currentCommand._errFile ){
      Shell::_currentCommand._outFile = new std::string($2->c_str());
      Shell::_currentCommand._errFile = new std::string($2->c_str());
      Shell::_currentCommand._append = true;
    }
    else{
      fprintf(stderr, "Ambiguous output redirect.\n");
    }
  }
  | GREATAMPERSAND WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());

    if (  !Shell::_currentCommand._outFile & !Shell::_currentCommand._errFile ){
      Shell::_currentCommand._outFile = new std::string($2->c_str());
      Shell::_currentCommand._errFile = new std::string($2->c_str());
    }
    else {
      fprintf(stderr, "Ambiguous output redirect.\n");
    }
  }
  | LESS WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | TWOGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if ( Shell::_currentCommand._errFile ) { 
      printf("Ambiguous error redirect.\n"); 
      exit(1); 
    }
    else  {
      Shell::_currentCommand._errFile = $2;
    }
  }
  ;



background_optional:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /*empty*/
  ;




%%

int maxEntries;
int nEntries;
char **entries;

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

int cmpfunc (const void * a, const void * b) {
  const char* a_str = *(const char **)a;
  const char* b_str = *(const char **)b;
  return strcmp(a_str, b_str);
}

void expandWildcardsIfNecessary(std::string *arg) {
  maxEntries = 20;
  nEntries = 0;
  entries = (char **) malloc (maxEntries * sizeof(char *));
  if (strchr(arg->c_str(), '*') || strchr(arg->c_str(), '?')) {
    expandWildcard(NULL, (char *)(arg->c_str()));
    if(!entries[0]){
      Command::_currentSimpleCommand->insertArgument(arg);
    }
    //sort all files matches regex
    qsort(entries, nEntries, sizeof(char *), cmpfunc);
    //add them to argument
    for (int i = 0; i < nEntries; i++){
      std::string *s = new std::string(entries[i]);
      Command::_currentSimpleCommand->insertArgument(s);
    }
  }
  else {
    Command::_currentSimpleCommand->insertArgument(arg);
    return;
  }
  return;
}




void expandWildcard(char *prefix, char *suffix) {
  //convert "*" -> ".*"
  // "?" -> "/"
  // "." -> "\."
  char *rest = suffix;
  char *temp = (char*)malloc(2*strlen(suffix) + 10);
  char *current = temp;
  if (*rest == '/') {
    *temp = *rest;
    temp++;
    rest++;
  }
  while(*rest != '/' && *rest) {
    *temp = *rest;
    rest++; temp++;
  }
  *temp = '\0';


  if(!strchr(current, '*') && !strchr(current, '?')){
    char *direct = (char *) malloc(50);
    if(prefix) {
        sprintf(direct, "%s%s", prefix, current);
    }
    else {
      sprintf(direct, "%s", current);
    }
    expandWildcard(direct, rest);
    return;
  }
  if (!prefix && suffix[0] == '/') {
    prefix = strdup("/");
    current++;
  }

  char *reg = (char*)malloc(2*strlen(suffix) + 10);
  char *a = (char*)malloc(strlen(suffix) + 1);
  strcpy(a, current);
  char *r = reg;
  *r = '^';
  r++;
  // match beginning of line

  while(*a) {
    if (*a == '*') { *r='.'; r++; *r='*'; r++; }
    else if(*a == '?') { *r='.'; r++; }
    else if(*a == '.') { *r='\\'; r++; *r='.'; r++; }
    else if(*a == '/') { }
    else { *r=*a; r++; }
    a++;
  }
  *r='$';
  r++;
  *r=0; //match end of line and add null char
  //compile regular expression
  regex_t re;
  int expbuf = regcomp( &re, reg, REG_EXTENDED|REG_NOSUB);
  if (expbuf != 0){
    perror("wrong regex");
    exit(-1);
  }
  //List directory and add as arguments the entries that match the regular expression
  DIR *dir;
  std::string path;
  char *t;
  char *c = (char*)malloc(strlen(suffix) + 1);
  strcpy(c, suffix);

  dir = opendir(strdup((prefix)?prefix:"."));

  if(dir == NULL) {
    perror("opendir");
    return;
  }

    struct dirent *ent;
    regmatch_t match;
    std::vector<char *> sortArgument = std::vector<char *>();
    while ((ent = readdir(dir)) != NULL) {
      //check if name matches
      if(regexec(&re, ent->d_name, 1, &match, 0) == 0) {
        //Add argument
        if(*rest) {
          if (ent->d_type == DT_DIR) {
            char *newa = (char *) malloc (100);
            if (!strcmp(strdup((prefix)?prefix:"."), ".")) {
              newa = strdup(ent->d_name);
            }
            else if(!strcmp(strdup((prefix)?prefix:"."), "/")) {
                sprintf(newa, "%s%s", strdup((prefix)?prefix:"."), ent->d_name);
            }
            else {
                sprintf(newa, "%s/%s", strdup((prefix)?prefix:"."), ent->d_name);
            }
            expandWildcard(newa, (*rest == '/')?++rest:rest);
          }
        }
        else {
          if (nEntries == maxEntries) {
              maxEntries *= 2;
              entries = (char **) realloc (entries, maxEntries * sizeof(char *)); 
          }
          char * argument = (char *) malloc (100);
          argument[0] = '\0';
          if(prefix){
            sprintf(argument, "%s/%s", prefix, ent->d_name);
          }

          if (ent->d_name[0] == '.') {
           if (suffix[0] == '.') {
             entries[nEntries] = (argument[0] != '\0')?strdup(argument):strdup(ent->d_name);
             nEntries++;
            }
          }
          else {
            entries[nEntries] = (argument[0] != '\0')?strdup(argument):strdup(ent->d_name);
            nEntries++;
          }
       }
     }
    }
    closedir(dir);
    regfree(&re);

  std::sort(sortArgument.begin(), sortArgument.end(), cmpfunc);
  for (auto a: sortArgument) {
    std::string * argToInsert = new std::string(a);
    Command::_currentSimpleCommand->insertArgument(argToInsert);
  }
  sortArgument.clear();
}


#if 0
main()
{
  yyparse();
}
#endif
