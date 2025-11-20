package controllers

import javax.inject._
import play.api.mvc._
import play.api.libs.json._
import models._
import java.time.Instant

@Singleton
class ApiController @Inject()(val controllerComponents: ControllerComponents) extends BaseController {

  // Simple GET endpoint
  def hello = Action {
    Ok(Json.obj(
      "message" -> "Hello from Scala Play!"
    ))
  }

  // GET with parameter
  def echo(text: String) = Action {
    Ok(Json.obj(
      "echo" -> text,
      "length" -> text.length
    ))
  }

  // POST endpoint with JSON body
  def postData = Action(parse.json) { request =>
    request.body.validate[DataRequest].fold(
      errors => BadRequest(Json.obj("error" -> JsError.toJson(errors))),
      dataRequest => {
        val response = DataResponse.create(dataRequest)
        Ok(Json.toJson(response))
      }
    )
  }

  // CPU intensive endpoint for performance testing
  def compute(iterations: Int) = Action {
    var sum: Long = 0
    for (i <- 0 until iterations) {
      sum += i
    }
    Ok(Json.obj(
      "result" -> sum,
      "iterations" -> iterations
    ))
  }

  // Memory allocation endpoint for RAM testing
  def memory(sizeMb: Int) = Action {
    val data = Array.fill(sizeMb * 1024 * 1024)(42.toByte)
    val checksum = data.map(_.toLong).sum
    Ok(Json.obj(
      "allocated" -> s"${sizeMb}MB",
      "checksum" -> checksum
    ))
  }

  // JSON serialization/deserialization benchmark
  def jsonBenchmark = Action(parse.json) { request =>
    val objectCount = (request.body \ "objectCount").as[Int]

    val startSerialize = System.nanoTime()

    // Create large object to serialize
    val data = (0 until objectCount).map { i =>
      PersonData(
        id = i,
        name = s"Person $i",
        email = s"person$i@example.com",
        age = 20 + (i % 50),
        address = AddressData(
          street = s"$i Main St",
          city = "TestCity",
          zipCode = s"${10000 + i}",
          country = "TestCountry"
        )
      )
    }.toList

    val serializeTime = (System.nanoTime() - startSerialize) / 1000000.0

    // Serialize to JSON
    val startJsonSerialize = System.nanoTime()
    val json = Json.toJson(data).toString()
    val jsonSerializeTime = (System.nanoTime() - startJsonSerialize) / 1000000.0

    // Deserialize back
    val startDeserialize = System.nanoTime()
    val deserialized = Json.parse(json).as[List[PersonData]]
    val deserializeTime = (System.nanoTime() - startDeserialize) / 1000000.0

    Ok(Json.obj(
      "objectCount" -> objectCount,
      "objectCreationTimeMs" -> serializeTime,
      "serializationTimeMs" -> jsonSerializeTime,
      "deserializationTimeMs" -> deserializeTime,
      "totalTimeMs" -> (serializeTime + jsonSerializeTime + deserializeTime),
      "jsonSizeBytes" -> json.length
    ))
  }

  // LINQ equivalent (Scala collections) vs imperative loops benchmark
  def linqBenchmark(size: Int) = Action {
    val data = (1 to size).toList

    // Functional operations (equivalent to LINQ)
    val startFunctional = System.nanoTime()
    val functionalResult = data
      .filter(_ % 2 == 0)
      .map(_ * 2)
      .sortWith(_ > _)
      .take(100)
    val functionalTime = (System.nanoTime() - startFunctional) / 1000000.0

    // Imperative operations with loops
    val startLoop = System.nanoTime()
    val loopResult = scala.collection.mutable.ArrayBuffer[Int]()
    var i = 0
    while (i < data.length) {
      if (data(i) % 2 == 0) {
        loopResult += data(i) * 2
      }
      i += 1
    }
    val sorted = loopResult.sorted.reverse
    val finalResult = if (sorted.length > 100) sorted.take(100) else sorted
    val loopTime = (System.nanoTime() - startLoop) / 1000000.0

    // Complex functional query
    val startComplex = System.nanoTime()
    val complexResult = data
      .groupBy(_ % 10)
      .map { case (key, values) =>
        Json.obj(
          "Key" -> key,
          "Sum" -> values.sum,
          "Count" -> values.length,
          "Average" -> values.sum.toDouble / values.length
        )
      }
      .toList
      .sortBy(obj => (obj \ "Sum").as[Int])(Ordering[Int].reverse)
    val complexTime = (System.nanoTime() - startComplex) / 1000000.0

    Ok(Json.obj(
      "dataSize" -> size,
      "functionalTimeMs" -> functionalTime,
      "forLoopTimeMs" -> loopTime,
      "complexFunctionalTimeMs" -> complexTime,
      "functionalSlowerByPercent" -> (if (loopTime > 0) ((functionalTime - loopTime) / loopTime) * 100 else 0),
      "resultCount" -> functionalResult.length
    ))
  }

  // Collection operations benchmark
  def collectionBenchmark(size: Int) = Action {
    // List operations
    val startList = System.nanoTime()
    val list = scala.collection.mutable.ListBuffer[Int]()
    for (i <- 0 until size) list += i
    val listAddTime = (System.nanoTime() - startList) / 1000000.0

    val startListSearch = System.nanoTime()
    val found1 = list.contains(size / 2)
    val listSearchTime = (System.nanoTime() - startListSearch) / 1000000.0

    // Array operations
    val startArray = System.nanoTime()
    val array = new Array[Int](size)
    for (i <- 0 until size) array(i) = i
    val arrayAddTime = (System.nanoTime() - startArray) / 1000000.0

    val startArraySearch = System.nanoTime()
    val found2 = array.contains(size / 2)
    val arraySearchTime = (System.nanoTime() - startArraySearch) / 1000000.0

    // Set operations
    val startSet = System.nanoTime()
    val set = scala.collection.mutable.HashSet[Int]()
    for (i <- 0 until size) set += i
    val setAddTime = (System.nanoTime() - startSet) / 1000000.0

    val startSetSearch = System.nanoTime()
    val found3 = set.contains(size / 2)
    val setSearchTime = (System.nanoTime() - startSetSearch) / 1000000.0

    Ok(Json.obj(
      "dataSize" -> size,
      "list" -> Json.obj("addTimeMs" -> listAddTime, "searchTimeMs" -> listSearchTime),
      "array" -> Json.obj("addTimeMs" -> arrayAddTime, "searchTimeMs" -> arraySearchTime),
      "set" -> Json.obj("addTimeMs" -> setAddTime, "searchTimeMs" -> setSearchTime)
    ))
  }
}
