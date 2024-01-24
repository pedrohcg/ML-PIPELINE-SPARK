from pyspark.sql import SparkSession
from pyspark.ml import PipelineModel

spark = SparkSession.builder.appName("Deply").getOrCreate()

modelo = PipelineModel.load("hdfs:///opt/spark/data/modelo")

novos_dados = spark.read.csv("hdfs:///opt/spark/data/novosdados.csv", header=True, inferSchema=True)

previsoes = modelo.transform(novos_dados)

selected_columns = ["Idade", "UsoMensal", "Plano", "SatisfacaoCliente", "TempoContrato", "ValorMensal", "prediction"]
previsoes_para_salvar = previsoes.select(selected_columns)

previsoes_para_salvar.write.csv("hdfs:///opt/spark/data/previsoesnovosdados", mode="overwrite")

spark.stop()