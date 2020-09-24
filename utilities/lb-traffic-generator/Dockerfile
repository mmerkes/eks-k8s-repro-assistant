FROM ubuntu 
ADD ./hammertime.sh /usr/src/hammertime.sh
RUN chmod +x /usr/src/hammertime.sh
RUN yes | apt-get update;  yes | apt-get install curl
CMD ["/usr/src/hammertime.sh"]
