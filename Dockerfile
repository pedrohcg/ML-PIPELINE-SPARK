FROM python:3.11-bullseye as spark-base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        curl \
        vim \
        nano \
        unzip \
        rsync \
        openjdk-11-jdk \
        build-essential \
        software-properties-common \
        ssh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SPARK_HOME=${SPARK_HOME:-"/opt/spark"}
ENV HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}

RUN mkdir -p ${HADOOP_HOME} && mkdir -p ${SPARK_HOME}
WORKDIR ${SPARK_HOME}

RUN curl https://dlcdn.apache.org/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz -o spark-3.5.0-bin-hadoop3.tgz \
    && tar xvzf spark-3.5.0-bin-hadoop3.tgz --directory /opt/spark --strip-components 1 \
    && rm -rf spark-3.5.0-bin-hadoop3.tgz

# Download dos binarios do hadoop
RUN curl https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz -o hadoop-3.3.6.tar.gz \
    && tar xfz hadoop-3.3.6.tar.gz --directory /opt/hadoop --strip-components 1 \
    && rm -rf hadoop-3.3.6.tar.gz

# Prepara o ambiente como pyspark
FROM spark-base as pyspark

# Instala as dependencias do Python
RUN pip3 install --upgrade pip
COPY requirements/requirements.txt .
RUN pip3 install -r requirements.txt

# Variavel de ambiente do JAVA_HOME necessario para configurar o hadoop
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

# Adiciona os bianrios do spark, Java e hadoop no path
ENV PATH="$SPARK_HOME/sbin:/opt/spark/bin:${PATH}"
ENV PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:${PATH}"
ENV PATH="${PATH}:${JAVA_HOME}/bin"

ENV SPARK_MASTER="spark://spark-master-yarn:7077"
ENV SPARK_MASTER_HOST spark-master-yarn
ENV SPARK_MASTER_PORT 7077
ENV SPARK_PYTHON python3
ENV HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

# hadoop native library
ENV LD_LIBRARY_PATH="$HADOOP_HOME/lib/native:${LD_LIBTARY_PATH}"

# Usuario HDFS e Yarn
ENV HDFS_NAMENODE_USER="root"
ENV HDFS_DATANODE_USER="root"
ENV HDFS_SECONDARYNAMENODE_USER="root"
ENV YARN_RESOURCEMANAGER_USER="root"
ENV YARN_NODEMANAGER_USER="root"

# Adiciona JAVA_HOME ao arquivo de configuracao
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

#Copia os arquivos de configuracao
COPY yarn/spark-defaults.conf "$SPARK_HOME/conf/"
COPY yarn/*xml "$HADOOP_HOME/etc/hadoop"

# Faz com que os binarios sejam executaveis
RUN chmod u+x /opt/spark/sbin/* && \
    chmod u+x /opt/spark/bin/*

ENV PYTHONPATH=$SPARK_HOME/python/:$PYTHONPATH

#SSH para certificao sem senha no hadoop
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh//authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

#Copia o arquivo de conf do SSH
COPY ssh/ssh_config ~/.ssh/configuracao

COPY entrypoint.sh .

RUN chmod +x entrypoint.sh

EXPOSE 22

ENTRYPOINT [ "./entrypoint.sh" ]