FROM ubuntu 
ADD ./disk-io-generator.sh /usr/src/disk-io-generator.sh
RUN chmod +x /usr/src/disk-io-generator.sh
RUN yes | apt-get update;  yes | apt-get install curl
CMD ["/usr/src/disk-io-generator.sh"]
