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

case class AddressData(
  street: String,
  city: String,
  zipCode: String,
  country: String
)

object AddressData {
  implicit val format: Format[AddressData] = Json.format[AddressData]
}

case class PersonData(
  id: Int,
  name: String,
  email: String,
  age: Int,
  address: AddressData
)

object PersonData {
  implicit val format: Format[PersonData] = Json.format[PersonData]
}
