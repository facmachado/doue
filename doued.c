/**
 * doued.c - UInput device tiny server (keyboard and mouse)
 *
 * Copyright (c) 2022 Flavio Augusto (@facmachado)
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 *
 * Usage: doued (as root)
 */


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <libgen.h>
#include <linux/uinput.h>


/**
 * Flag for program finish
 */
int f = 1;


/**
 * Using the flag
 */
void stop(int e) {
  f = 0;
}


/**
 * main()
 */
int main(int argc, char **argv) {
  /* Security */
  // if (getuid() != 0) {
  //   printf("\x1b[1;31mSorry, you are not root\x1b[0m\n");
  //   exit(1);
  // }

  /* This app name */
  char *name = basename(argv[0]);

  /* Security 2 */
  int ld;
  char lock[16];
  sprintf(lock, "/tmp/%s.lock", name);
  if (!access(lock, F_OK)) {
    printf("\x1b[1;31mAnother %s may be already running\x1b[0m\n", name);
    exit(2);
  }
  ld = open(lock, O_CREAT | O_EXCL);

  /* Device setup */
  int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
  struct uinput_setup usetup;
  memset(&usetup, 0, sizeof(usetup));

  /* Device details */
  usetup.id.bustype = BUS_USB;
  usetup.id.vendor  = 0xd0ed;
  usetup.id.product = 0xd0ed;
  usetup.id.version = 0x1;
  strcpy(usetup.name, name);

  /* Events */
  ioctl(fd, UI_SET_EVBIT, EV_KEY);
  ioctl(fd, UI_SET_EVBIT, EV_REL);
  ioctl(fd, UI_SET_EVBIT, EV_SYN);
  for (int i = 0; i < 768; i++) {
    ioctl(fd, UI_SET_KEYBIT, i);
    ioctl(fd, UI_SET_RELBIT, i);
  }

  /* Startup */
  ioctl(fd, UI_DEV_SETUP, &usetup);
  ioctl(fd, UI_DEV_CREATE);
  signal(SIGINT, &stop); /* flag */
  printf("[Service %s running]\n", name);

  /* Main loop */
  while (f) sleep(10);

  /* Shutdown and teardown */
  printf("\r[Service %s stopped]\n", name);
  ioctl(fd, UI_DEV_DESTROY);
  close(fd);
  close(ld);
  unlink(lock);
}
