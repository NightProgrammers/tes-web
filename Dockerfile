FROM wuhuizuo/ruby

ADD ./ /app

WORKDIR /app
expose 9292

CMD ['./start.sh']
