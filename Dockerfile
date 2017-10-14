FROM wuhuizuo/docker-ruby

ADD ./ /app

WORKDIR /app

CMD ['./start.sh']
