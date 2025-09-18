---
title: "Protocol Mapping for SDF"
abbrev: "sdf-protocol-mapping"
category: std

docname: draft-ietf-asdf-sdf-protocol-mapping-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
area: "Applications and Real-Time"
workgroup: "A Semantic Definition Format for Data and Interactions of Things"
keyword:
 - IoT
venue:
  group: "A Semantic Definition Format for Data and Interactions of Things"
  type: "Working Group"
  mail: "asdf@ietf.org"
  github: "ietf-wg-asdf/sdf-protocol-mapping"

author:
 - name: Rohit Mohan
   org: Cisco Systems
   street: 170 West Tasman Drive
   code: 95134
   city: San Jose
   country: USA
   email: rohitmo@cisco.com

 - name: Bart Brinckman
   org: Cisco Systems
   street: 170 West Tasman Drive
   code: 95134
   city: San Jose
   country: USA
   email: bbrinckm@cisco.com

 - name: Lorenzo Corneo
   org: Ericsson
   street: Hirsalantie 11
   code: 02420
   city: Jorvas
   country: Finland
   email: lorenzo.corneo@ericsson.com

normative:
  I-D.ietf-asdf-sdf: sdf

informative:
  BLE53:
    title: "Bluetooth Core Specification Version 5.3"
    author:
      org: Bluetooth SIG
    date: 2021-07-13
    target: https://www.bluetooth.com/specifications/specs/core-specification-5-3/
  Zigbee22:
    title: "Zigbee 3.0 Specification"
    author:
      org: Zigbee Alliance
    date: 2022
    target: https://zigbeealliance.org/solution/zigbee/

...

--- abstract

This document defines protocol mapping extensions for the Semantic Definition
Format (SDF) to enable mapping of protocol-agnostic SDF affordances to
protocol-specific operations. The protocol mapping mechanism allows SDF models
to specify how properties, actions, and events should be accessed using specific
IP and non-IP protocols such as Bluetooth Low Energy, Zigbee or HTTP and CoAP.

--- middle

# Introduction

The Semantic Definition Format (SDF) {{-sdf}} provides a protocol-agnostic way
to describe IoT devices and their capabilities through properties, actions, and
events (collectively called affordances). However, when implementing these
affordances on actual devices using specific communication protocols, there
needs to be a mechanism to map the protocol-agnostic SDF definitions to
protocol-specific operations.

These protocols can be non-IP protocols that are commonly used in IoT
environments, such as {{BLE53}} and {{Zigbee22}}, or IP-based protocols, such as
HTTP {{?RFC2616}} or CoAP {{?RFC7252}}.

To leverage an SDF model to perform protocol-specific operations on an instance
of a device, a mapping of the SDF affordance to a protocol-specific attribute is
required. This document defines the protocol mapping mechanism using the
`sdfProtocolMap` keyword, which allows SDF models to include protocol-specific
mapping information alongside the protocol-agnostic definitions.


# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Structure

Protocol mapping is required to map a protocol-agnostic affordance to
a protocol-specific operation, as implementations of the same affordance
will differ between protocols. For example, BLE will address a property
as a service characteristic, while a property in Zigbee is addressed
as an attribute in a cluster of an endpoint.

A protocol mapping object is a JSON object identified by the `sdfProtocolMap`
keyword. Protocol-specific properties are embedded within this object, organized
by protocol name, e.g., "ble" or "zigbee". The protocol name MUST be specified
in the IANA registry requested in {{iana-prot-map}}.

~~~ aasvg
sdfProtocolMap
  |
  +-----> ble
  |        |
  |        +--> BLE-specific mapping
  |
  +-----> zigbee
  |        |
  |        +--> Zigbee-specific mapping
  |
  +-----> openapi
           |
           +--> OpenAPI-specific mapping
~~~
{: #protmap title="Property Mapping"}

As shown in {{protmap}}, protocol-specific properties must be embedded in an
sdfProtocolMap object, for example a "ble" or a "zigbee" object.


| Attribute |  Type  |          Example                           |
+-----------+--------+--------------------------------------------|
| ble       | object | an object with BLE-specific attributes     |
| zigbee    | object | an object with Zigbee-specific attributes  |
| openapi   | object | an object with OpenAPI-specific attributes |
{: #proobj title="Protocol objects"}

where-

 - "ble" is an object containing properties that are specific to the BLE
   protocol.
 - "zigbee" is an object containing properties that are specific to the
   Zigbee protocol.
 - Other protocol mapping objects can be added by creating a new protocol
   object

Example protocol mapping:

~~~ json
{
  "sdfObject": {
    "healthsensor": {
      "sdfProperty": {
        "heartrate": {
          "description": "The current measured heart rate",
          "type": "number",
          "unit": "beat/min",
          "observable": false,
          "writable": false,
          "sdfProtocolMap": {
            "ble": {
              "serviceID": "12345678-1234-5678-1234-56789abcdef4",
              "characteristicID":
                "12345678-1234-5678-1234-56789abcdef4"
            }
          }
        }
      }
    }
  }
}
~~~
{: #exprotmap title="Example property mapping"}

For properties that have a different protocol mapping for read and write operations, the protocol mapping can be specified as such:

~~~ json
{
  "sdfObject": {
    "healthsensor": {
      "sdfProperty": {
        "heartrate": {
          "description": "The current measured heart rate",
          "type": "number",
          "unit": "beat/min",
          "observable": false,
          "sdfProtocolMap": {
            "ble": {
              "read": {
                "serviceID": "12345678-1234-5678-1234-56789abcdef4",
                "characteristicID":
                  "12345678-1234-5678-1234-56789abcdef5"
              },
              "write": {
                "serviceID": "12345678-1234-5678-1234-56789abcdef4",
                "characteristicID":
                  "12345678-1234-5678-1234-56789abcdef6"
              }
            }
          }
        }
      }
    }
  }
}
~~~
{: #exprotmap2 title="Example property mapping"}

# Usage

A protocol map MAY be provided as part of the SDF model, specifically in the SDF
affordance definition. The extension points in the SDF affordance definition
defined in {{-sdf}} are used to specify the protocol mapping information as a
part of the SDF model.

For SDF properties, the protocol mapping is specified as an
extension to a named property quality using the `sdfProtocolMap` keyword.
For SDF actions and events, the protocol mapping can be specified
as an extension to the named quality or as part of the `sdfInputData` or
`sdfOutputData` objects.

# Examples

## BLE Protocol Mapping

The BLE protocol mapping allows SDF models to specify how properties,
actions, and events should be accessed using Bluetooth Low Energy (BLE)
protocol. The mapping includes details such as service IDs and characteristic
IDs that are used to access the corresponding SDF affordances.

### BLE Protocol Mapping Structure

For SDF properties and actions, the BLE protocol mapping structure
is defined as follows:

~~~ cddl
{::include cddl/ble-protocol-map.cddl}
~~~
{: #blemap1 title="CDDL definition for BLE Protocol Mapping for properties and actions"}

Where:

- `serviceID` is the BLE service ID that corresponds to the SDF property or action.
- `characteristicID` is the BLE characteristic ID that corresponds to the SDF property or action.

For example, a BLE protocol mapping for a temperature property might look like:

~~~ json
{
  "sdfProperty": {
    "temperature": {
      "sdfProtocolMap": {
        "ble": {
          "serviceID": "12345678-1234-5678-1234-56789abcdef4",
          "characteristicID": "12345678-1234-5678-1234-56789abcdef5"
        }
      }
    }
  }
}
~~~

For SDF events, the BLE protocol mapping structure is similar, but it may
include additional attributes such as the type of the event.

~~~ cddl
{::include cddl/ble-event-map.cddl}
~~~
{: #blemap2 title="BLE Protocol Mapping for events"}

Where:

- `type` specifies the type of BLE event, such as "gatt" for GATT events,
  "advertisements" for advertisement events, or "connection_events" for
  connection-related events.
- `serviceID` and `characteristicID` are optional attributes that are
  specified if the type is "gatt".

For example, a BLE event mapping for a heart rate measurement event might look like:

~~~ json
{
  "sdfEvent": {
    "heartRate": {
      "sdfOutputData": {
        "sdfProtocolMap": {
          "ble": {
            "type": "gatt",
            "serviceID": "12345678-1234-5678-1234-56789abcdef4",
            "characteristicID": "12345678-1234-5678-1234-56789abcdef5"
          }
        }
      }
    }
  }
}
~~~

Another example of an `isPresent` event using BLE advertisements:

~~~ json
{
  "sdfEvent": {
    "isPresent": {
      "sdfOutputData": {
        "sdfProtocolMap": {
          "ble": {
            "type": "advertisements"
          }
        }
      }
    }
  }
}
~~~

## Zigbee Protocol Mapping

The Zigbee protocol mapping allows SDF models to specify how properties,
actions, and events should be accessed using the Zigbee protocol. The
mapping includes details such as cluster IDs and attribute IDs that are
used to access the corresponding SDF affordances.

### Zigbee Protocol Mapping Structure

For SDF properties and actions, the Zigbee protocol mapping structure
is defined as follows:

~~~ cddl
{::include cddl/zigbee-protocol-map.cddl}
~~~
{: #zigmap1 title="CDDL definition for Zigbee Protocol Mapping for properties and actions"}

Where:

- `endpointID` is the Zigbee endpoint ID that corresponds to the SDF affordance.
- `clusterID` is the Zigbee cluster ID that corresponds to the SDF affordance.
- `attributeID` is the Zigbee attribute ID that corresponds to the SDF affordance.
- `type` is the Zigbee data type of the attribute.

For example, a Zigbee protocol mapping for a temperature property might look like:

~~~ jsonc
{
  "sdfProperty": {
    "temperature": {
      "sdfProtocolMap": {
        "zigbee": {
          "endpointID": 1,
          "clusterID": 1026, // 0x0402
          "attributeID": 0, // 0x0000
          "type": 41 // 0x29
        }
      }
    }
  }
}
~~~

## IP based Protocol Mapping

The protocol mapping mechanism can potentially also be used for IP-based protocols
such as HTTP or CoAP. An example of a protocol mapping for a property using HTTP
might look like:

~~~ json
=============== NOTE: '\' line wrapping per RFC 8792 ================

{
  "sdfProperty": {
    "heartrate": {
      "sdfProtocolMap": {
        "openapi": {
            "operationRef": "https://example.com/openapi.json#/paths\
/~1heartrate~1{id}~1current",
            "$ref": "https://example.com/openapi.json#/components/sc\
hema/HeartRate/properties/pulse"
        }
      }
    }
  }
}
~~~

The `operationRef` points to the OpenAPI operation that retrieves the
current heart rate, and the `$ref` points to the OpenAPI schema that
defines the heart rate property. An example of the OpenAPI schema
might look like:

~~~ yaml
paths:
  /heartrate/{id}/current:
    get:
      summary: Get current heart rate
      description: |-
        Retrieve the current heart rate for a specific user
        identified by {id}.
      parameters:
        - name: id
          in: path
          required: true
          description: |-
            The ID of the user whose heart rate is being queried.
          schema:
            type: string
      responses:
        "200":
          description: |-
            Successful response with current heart rate data.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/HeartRate"
    put:
      summary: Set current heart rate
      description: |-
        Set the current heart rate for a specific user
        identified by {id}.
      parameters:
        - name: id
          in: path
          required: true
          description: |-
            The ID of the user whose heart rate is being set.
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/HeartRate"

components:
  schemas:
    HeartRate:
      type: object
      properties:
        pulse:
          type: integer
          description: The current heart rate in beats per minute.
        spo2:
          type: number
          format: float
          description: |-
            The current body temperature in degrees Celsius.
~~~

We assume that the readable properties will map to GET operations and the writable properties will map to PUT operations.
If this is not the case, or if the API is different, the protocol mapping can be specified as such:

~~~ json
=============== NOTE: '\' line wrapping per RFC 8792 ================

{
  "sdfProperty": {
    "heartrate": {
      "sdfProtocolMap": {
        "openapi": {
          "read": {
            "operationRef": "https://example.com/openapi.json#/paths\
/~1heartrate~1{id}~1current/get",
            "$ref": "https://example.com/openapi.json#/components/sc\
hema/HeartRate/properties/pulse"
          },
          "write": {
            "operationRef": "https://example.com/openapi.json#/paths\
/~1heartrate~1{id}~1current/put",
            "$ref": "https://example.com/openapi.json#/components/sc\
hema/HeartRate/properties/pulse"
          }
        }
      }
    }
  }
}
~~~

# Security Considerations

TODO Security


# IANA Considerations

This section provides guidance to the Internet Assigned Numbers Authority
(IANA) regarding registration of values related to this document,
in accordance with {{!RFC8126}}.


## Protocol mapping {#iana-prot-map}

IANA is requested to create a new registry called "SDF Protocol mapping".

The registry must contain following attributes:

- Protocol map name
- Protocol name
- Description
- Reference of the specification describing the protocol mapping. This specification must be reviewed by an expert.

Following protocol mappings are described in this document:

| Protocol map | Protocol Name               | Description                                 | Reference       |
|--------------|-----------------------------|---------------------------------------------|-----------------|
| ble          | Bluetooth Low Energy (BLE)  | Protocol mapping for BLE devices            | This document   |
| zigbee       | Zigbee                      | Protocol mapping for Zigbee devices         | This document   |
| openapi      | OpenAPI                     | Protocol mapping for OpenAPI                | This document   |
{: #protmap-reg title="Protocol Mapping Registry"}

--- back

# CDDL Definition

~~~ cddl
{::include cddl/sdf-protocol-map.cddl}

{::include cddl/ble-protocol-map.cddl}

{::include cddl/ble-event-map.cddl}

{::include cddl/zigbee-protocol-map.cddl}
~~~

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
