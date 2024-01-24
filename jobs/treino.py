from pyspark.sql import SparkSession
from pyspark.sql import Row
from pyspark.ml import Pipeline
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator

spark = SparkSession.builder.appName("Treino").getOrCreate()

df = spark.read.csv("hdfs:///opt/spark/data/dataset.csv", header=True, inferSchema=True)

# Transforma as colunas em string para números
indexers = [StringIndexer(inputCol=column, outputCol=column+"_index").fit(df) for column in ["Plano", "TempoContrato"]]

# Cria um vetor com todas as colunas
assembler = VectorAssembler(inputCols = ["Idade", "UsoMensal", "SatisfacaoCliente", "ValorMensal", "Plano_index", "TempoContrato_index"], outputCol="features")

dados_treino, dados_teste = df.randomSplit([0.7, 0.3])

# Inicializa o modelo
modelo_rf = RandomForestClassifier(labelCol="Churn", featuresCol="features")

pipeline = Pipeline(stages=indexers + [assembler, modelo_rf])

modelo = pipeline.fit(dados_treino)

previsoes = modelo.transform(dados_teste)

avaliador = BinaryClassificationEvaluator(labelCol="Churn")
acuracia = avaliador.evaluate(previsoes)

acuracia_df = spark.createDataFrame([Row(acuracia=acuracia)])

selected_columns = ["Idade", "UsoMensal", "Plano", "SatisfacaoCliente", "TempoContrato", "ValorMensal", "Churn", "prediction"]
previsoes_para_salvar = previsoes.select(selected_columns)

modelo.write().overwrite().save("hdfs:///opt/spark/data/modelo")
acuracia_df.write.csv("hdfs:///opt/spark/data/acuracia", mode="overwrite")
previsoes_para_salvar.write.csv("hdfs:///opt/spark/data/previsoes", mode="overwrite")

spark.stop()