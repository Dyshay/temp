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
      "message" -> "Hello from Scala Play!",
      "timestamp" -> Instant.now().toString
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
}
