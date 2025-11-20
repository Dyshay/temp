package models

import play.api.libs.json._
import java.time.Instant
import java.util.UUID

case class DataRequest(name: String, value: Int)

object DataRequest {
  implicit val format: Format[DataRequest] = Json.format[DataRequest]
}

case class DataResponse(
  id: String,
  receivedName: String,
  receivedValue: Int,
  processedAt: String
)

object DataResponse {
  implicit val format: Format[DataResponse] = Json.format[DataResponse]

  def create(request: DataRequest): DataResponse = {
    DataResponse(
      id = UUID.randomUUID().toString,
      receivedName = request.name,
      receivedValue = request.value,
      processedAt = Instant.now().toString
    )
  }
}
