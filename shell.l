/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%s incl

%{

#include <cstring>
#include "y.tab.hh"
#include <sys/wait.h>
#include <unistd.h>
#include <string>
#define MAX_INCLUDE_DEPTH 10
YY_BUFFER_STATE include_stack[MAX_INCLUDE_DEPTH];
int include_stack_ptr = 0;

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap


%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

">>" {
  return GREATGREAT;
}

"<" {
  return LESS;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"2>" {
  return TWOGREAT;
}

source {
  BEGIN(incl);
}

<incl>[ \t]*
<incl>[^ \t\n]+ {
    if (include_stack_ptr >= MAX_INCLUDE_DEPTH) {
        fprintf(stderr, "Includes nested too deeply");
        exit(1);
    }

    include_stack[include_stack_ptr++] = YY_CURRENT_BUFFER;

    yyin = fopen(yytext, "r");

    if (!yyin) {
        perror("source");
    }

    yy_switch_to_buffer(
        yy_create_buffer(yyin, YY_BUF_SIZE));

    BEGIN(INITIAL);
}

<<EOF>> {
    if (--include_stack_ptr == 1) {
        yyterminate();
    } else {
        yy_delete_buffer(YY_CURRENT_BUFFER);
        yy_switch_to_buffer(
        include_stack[include_stack_ptr]);
    }
}

[~][^ \n\t]* {
  std::string *str = new std::string(yytext);
  std::string h = getenv("HOME");
  if (str->size() == 1) {
    yylval.cpp_string = new std::string(h);
    return WORD;
  }
  else {
    if (strcmp(str->substr(1,1).c_str(), "/") == 0) {
      h += str->substr(1,-1);
    }
    else {
      h = std::string("/homes/") + str->substr(1,-1);
    }
    yylval.cpp_string = new std::string(h);
    return WORD;
  }
}

\$\{[^ \}\n]*\}([^ \n]*|\$\{[^ \}\n]*\})* {
  std::string *str = new std::string(yytext);
  std::string res = "";
  int start = 0;
  int end = str->find('$');
  bool a = true;
  while(a) {
    res += str->substr(start, end-start);
    std::string temp = str->substr(end+2, str->find('}', end)-end-2 );
    if (strcmp(temp.c_str(), "$") == 0){
      pid_t pid = getpid();
      res += std::to_string(pid);
      yylval.cpp_string = new std::string(res);
      return WORD;
    }
    if (strcmp(temp.c_str(), "?") == 0){
      
    }
    if (strcmp(temp.c_str(), "!") == 0){

    }
    if (strcmp(temp.c_str(), "_") == 0){

    }
    if (strcmp(temp.c_str(), "SHELL") == 0){

    }
    if (getenv(temp.c_str())) {
        res += getenv(temp.c_str());
    }
    if (str->find('$', end+1) == -1){
      a = false;
    }
    start = str->find('}', start) + 1;
    end = str->find('$', end+1);
  }
  res += str->substr(start, -1);
  yylval.cpp_string = new std::string(res);
  return WORD;
}

\$\([^\n\$]*\)|`[^\n`]*` {
  std::string *str = new std::string(yytext);
  int len = str->length();
  // string check
  if (str->at(0) == '`' && str->at(len-1) == '`') {
      str = new std::string(yytext+1, len-3);
  }
  else {
      str = new std::string(yytext+2, len-3);
  }
    //parent creates two pipes
  int pin[2];
  int pout[2];
  int tmpin = dup(0);
  int tmpout = dup(1);

  pipe(pin);
  pipe(pout);

  write(pin[1], str->c_str(), str->size());
  write(pin[1], "\nexit\n",6);
  close(pin[1]);

  dup2(pin[0], 0);
  close(pin[0]);
  dup2(pout[1], 1);
  close(pout[1]);

  //parent creates child process
  int ret = fork();
  if (ret == 0) {
    execvp("/proc/self/exe", NULL);
    exit(1);
  }
  else if (ret < 0) {
      perror("fork");
      exit(1);
  }

  dup2(tmpin, 0);
  dup2(tmpout, 1);
  close(tmpin);
  close(tmpout);

  char ch;
  size_t size = 0;
  int i = 0;

  char * buffer = new char[6666];
  while (read(pout[0], &ch, 1)) {
      if (ch == '\n') {
         buffer[i++] = ' ';
      } else {
          buffer[i++] = ch;
      }
  }
  buffer[i] = '\0';

  size_t len1 = strlen(buffer);
  for (int j = len1 - 1; j >= 0; j--) {
      unput(buffer[j]);
  }


}

 [^ \t\n|><&]*\\[^ \t\n]* {
 // escape
  char *res = new char[strlen(yytext)];
  char *copy = yytext;
  int i = 0;
  int count = 0;
  while (i < strlen(yytext)) {
    if (copy[i] != '\\') {
      res[count] = copy[i];
      count += 1;
    }
    else if ((i+1) < strlen(yytext) & copy[i+1] == '\\' ){
      res[count] = '\\';
      count += 1;
      i++;
    }
    i++;
  }
  res[count] = '\0';
  yylval.cpp_string = new std::string(res);
  return WORD;
 }

["][^\n\"]*["] {
  // Quotes
  std::string str = std::string(yytext);
  str = str.substr(1,str.size()-2);
  yylval.cpp_string = new std::string(str);
  return WORD;
}


[^ \t\n|><][^ \t\n|><]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

