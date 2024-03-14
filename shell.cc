#include <cstdio>
#include <signal.h>
#include "shell.hh"
#include <sys/wait.h>
#include <string.h>
#include <unistd.h>
int yyparse(void);
void yyrestart(FILE * input_file );

void Shell::prompt() {
  fflush(stdout);
}

extern "C" void ctrl_c ( int sig ) {
  fprintf(stderr, "\nsig: %d ctrl-c interrupted\n", sig);
}
extern "C" void zombie(int sig) {
  int pid = wait3(0, 0, NULL);
  while (waitpid(-1, NULL, WNOHANG) > 0) {

  };
}


int main(int argc, char **argv) {

  char abs_path[256];
  realpath(argv[0], abs_path);
  setenv("SHELL", abs_path, 1);

  struct sigaction sa;
  sa.sa_handler = ctrl_c;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  if(sigaction(SIGINT, &sa, NULL)){
    perror("sigaction");
    exit(EXIT_FAILURE);
  }
  struct sigaction sa2;
  sa2.sa_handler = zombie;
  sigemptyset(&sa2.sa_mask);
  sa2.sa_flags = SA_RESTART;
  if(sigaction(SIGCHLD, &sa2, NULL)){
    perror("sigaction");
    exit(EXIT_FAILURE);
  }
  yyrestart(stdin);
  yyparse();
}

Command Shell::_currentCommand;
