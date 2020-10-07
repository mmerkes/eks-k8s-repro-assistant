FROM ubuntu
ADD ./git-cloner.sh /usr/src/git-cloner.sh
RUN chmod +x /usr/src/git-cloner.sh
RUN yes | apt-get update; yes | apt-get install git; yes | apt-get install tar
CMD ["/usr/src/git-cloner.sh"]
