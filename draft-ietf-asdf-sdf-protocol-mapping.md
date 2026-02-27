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
  RFC8610: cddl
  RFC9880: sdf

informative:
  BLE53:
    title: "Bluetooth Core Specification Version 5.3"
    author:
      org: Bluetooth SIG
    date: 2021-07-13
    target: https://www.bluetooth.com/specifications/specs/core-specification-5-3/
  Zigbee30:
    title: "Zigbee 3.0 Specification"
    author:
      org: CSA IoT
    date: 2026
    target: https://csa-iot.org/all-solutions/zigbee/

...

--- abstract

This document defines protocol mapping extensions for the Semantic Definition
Format (SDF) to enable mapping of protocol-agnostic SDF affordances to
protocol-specific operations. The protocol mapping mechanism allows SDF models
to specify how properties, actions, and events should be accessed using specific
non-IP and IP protocols such as Bluetooth Low Energy, Zigbee or HTTP and CoAP.
This document also describes a method to extend SCIM with an SDF model mapping.

--- middle

<!-- LC: Question about the title, how about SDF Protocol Mapping? This would
also match the keyword. -->

# Introduction

The Semantic Definition Format (SDF) {{-sdf}} provides a protocol-agnostic way
to describe IoT devices and their capabilities through properties, actions, and
events (collectively called affordances). When implementing an SDF model for a
device using specific communication protocols, there needs to be a mechanism to
map the protocol-agnostic SDF definitions to protocol-specific operations,
translating the model into a real-world implementation. Moreover, such mechanism
needs to be extensible for enabling implementors to provide novel SDF protocol
mappings to expand the SDF ecosystem. SDF protocol mappings may target a variety
of protocols spanning from non-IP protocols commonly used in IoT environments,
such as {{BLE53}} and {{Zigbee30}}, to IP-based protocols such as HTTP
{{?RFC9110}} and CoAP {{?RFC7252}}. This document provides the required
mechanism by defining:

<!-- LC: Introduced MAY as `sdfProtocolMap` is optional for SDF affordances -->
- The `sdfProtocolMap` keyword, which allows SDF models to include
  protocol-specific mapping information attached to the protocol-agnostic
  definitions, see {{sdf-pm}}. An `sdfProtocolMap` MAY be applied to an SDF
  affordance, be it an `sdfProperty`, `sdfEvent` or `sdfAction`. The mapping
  enables use cases such as application gateways or multi-protocol gateways that
  translate between different IoT protocols, automated generation of
  protocol-specific implementations from SDF models, and interoperability across
  heterogeneous device ecosystems.

- Two SDF protocol mappings for Bluetooth and Zigbee protocols, see {{ble-pm}}
  and {{zigbee-pm}} respectively.

- An SDF model extension for SCIM. While SDF provides a way to describe a class
  of devices, SCIM describes a device instance. The SDF model extension for SCIM
  enables the inclusion of SDF models for the class of devices a device belongs
  to in the SCIM object, see {{scim-sdf-extension}}.

- A IANA registry for defining additional SDF protocol mappings (in addition to
  the BLE and Zigbee provided in this document), see {{iana-prot-map}}.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# SDF Protocol Mapping Structure {#sdf-pm}

This section defines the structure of an `sdfProtocolMap`. Because each protocol
has its own addressing model, a single SDF affordance requires a distinct
mapping per protocol. For example, BLE addresses a property as a service
characteristic, while Zigbee addresses it as an attribute in a cluster of an
endpoint.

A protocol mapping object is a JSON object identified by the `sdfProtocolMap`
keyword, nested inside an SDF affordance definition (`sdfProperty`, `sdfAction`,
or `sdfEvent`). Protocol-specific attributes are embedded within this object,
keyed by an IANA registered protocol name, e.g., "ble" or "zigbee".

~~~ aasvg
sdfProperty / sdfAction / sdfEvent
  |
  +-----> sdfProtocolMap
            |
            +-----> ble
            |        |
            |        +--> BLE-specific mapping
            |
            +-----> zigbee
            |        |
            |        +--> Zigbee-specific mapping
            |
            +-----> ...
~~~
{: #protmap title="SDF Protocol Mapping Structure"}

## SDF Extension Points

The `sdfProtocolMap` keyword is introduced into SDF affordance definitions
through the extension points defined in the formal syntax of {{-sdf}}
(Appendix A). For each affordance type, an `sdfProtocolMap` entry is added
via the corresponding CDDL group socket. The contents of the
`sdfProtocolMap` object are in turn extensible through a
protocol-mapping-specific group socket.

A protocol MAY choose to extend only the affordance types that are applicable to
it. For example, the BLE protocol mapping defines extensions for properties and
events but not for actions.

### Property Extension {#property-extension}

The `$$SDF-EXTENSION-PROPERTY` group socket in the `propertyqualities`
rule of {{-sdf}} (Appendix A) is used to add protocol mapping to
`sdfProperty` definitions:

~~~ cddl
{::include cddl/sdf-property-protocol-map.cddl}
~~~
{: #sdf-prop-ext title="SDF Property Extension Point for Protocol Mapping"}

The `property-protocol-map` generic ({{sdf-prop-ext}}) captures the common
structure of property protocol mappings. The `name` parameter is the protocol
name and `props` is the protocol-specific map of attributes. A protocol can
provide either:

- A single mapping that applies to both read and write operations, or
- Separate `read` and `write` mappings when the protocol uses different
  attributes for each direction.

To extend `$$SDF-PROPERTY-PROTOCOL-MAP` for a new protocol (e.g.,
"new-protocol"), implementors MUST use the `property-protocol-map` generic with
the protocol name and a map type defining the protocol-specific attributes.

It is to be noted that the protocol `name` (e.g., "new-protocol") MUST be
registered in the IANA registry defined in {{iana-prot-map}}.

For example:

~~~ cddl
$$SDF-PROPERTY-PROTOCOL-MAP //= (
  property-protocol-map<"new-protocol", new-protocol-property>
)

new-protocol-property = {
  attributeA: text,
  attributeB: uint
}
~~~
{: #prop-ext-example title="Example Property Protocol Map Extension"}

The corresponding JSON in an SDF model looks like:

~~~ json
{
  "sdfProperty": {
    "temperature": {
      "type": "number",
      "unit": "Cel",
      "sdfProtocolMap": {
        "new-protocol": {
          "attributeA": "temperature-service",
          "attributeB": 1
        }
      }
    }
  }
}
~~~
{: #prop-ext-json-example title="Example Property Protocol Map in JSON"}

When a property uses different protocol attributes for read and write
operations, the mapping can be split:

~~~ json
{
  "sdfProperty": {
    "temperature": {
      "type": "number",
      "unit": "Cel",
      "sdfProtocolMap": {
        "new-protocol": {
          "read": {
            "attributeA": "temperature-read-service",
            "attributeB": 1
          },
          "write": {
            "attributeA": "temperature-write-service",
            "attributeB": 2
          }
        }
      }
    }
  }
}
~~~
{: #prop-ext-rw-json-example title="Example Property Protocol Map with Read/Write in JSON"}

### Action Extension {#action-extension}

The `$$SDF-EXTENSION-ACTION` group socket in the `actionqualities`
rule of {{-sdf}} (Appendix A) is used to add protocol mapping to
`sdfAction` definitions:

~~~ cddl
{::include cddl/sdf-action-protocol-map.cddl}
~~~
{: #sdf-action-ext title="SDF Action Extension Point for Protocol Mapping"}


Actions use a simpler structure than properties, as they do not require the
read/write distinction. To extend `$$SDF-ACTION-PROTOCOL-MAP` for a new
protocol, implementors MUST add a group entry that maps the protocol name to the
protocol-specific attributes:

~~~ cddl
$$SDF-ACTION-PROTOCOL-MAP //= (
  "new-protocol": new-protocol-action
)

new-protocol-action = {
  commandID: uint
}
~~~
{: #action-ext-example title="Example Action Protocol Map Extension"}

The corresponding JSON in an SDF model would look like:

~~~ json
{
  "sdfAction": {
    "reset": {
      "sdfProtocolMap": {
        "new-protocol": {
          "commandID": 42
        }
      }
    }
  }
}
~~~
{: #action-ext-json-example title="Example Action Protocol Map in JSON"}

### Event Extension {#event-extension}

The `$$SDF-EXTENSION-EVENT` group socket in the `eventqualities`
rule of {{-sdf}} (Appendix A) is used to add protocol mapping to
`sdfEvent` definitions:

~~~ cddl
{::include cddl/sdf-event-protocol-map.cddl}
~~~
{: #sdf-event-ext title="SDF Event Extension Point for Protocol Mapping"}

Events follow the same simple pattern as actions. To extend
`$$SDF-EVENT-PROTOCOL-MAP` for a new protocol:

~~~ cddl
$$SDF-EVENT-PROTOCOL-MAP //= (
  "new-protocol": new-protocol-event
)

new-protocol-event = {
  eventID: uint
}
~~~
{: #event-ext-example title="Example Event Protocol Map Extension"}

The corresponding JSON in an SDF model looks like:

~~~ json
{
  "sdfEvent": {
    "alert": {
      "sdfProtocolMap": {
        "new-protocol": {
          "eventID": 3
        }
      }
    }
  }
}
~~~
{: #event-ext-json-example title="Example Event Protocol Map in JSON"}

# New Protocol Registration Procedure {#protocol-registration}

Protocol names used as keys in the `sdfProtocolMap` object (e.g., "ble",
"zigbee") MUST be registered in the IANA registry defined in
{{iana-prot-map}}.

A new SDF protocol mapping MUST be defined by a specification that mandatorily
includes:

- A CDDL definition that extends at least one of the group sockets
  defined in this document:
  `$$SDF-PROPERTY-PROTOCOL-MAP` ({{property-extension}}),
  `$$SDF-ACTION-PROTOCOL-MAP` ({{action-extension}}), or
  `$$SDF-EVENT-PROTOCOL-MAP` ({{event-extension}}).
  Property mappings SHOULD use the `property-protocol-map` generic
  ({{property-extension}}) to ensure a consistent structure.
- A description of the protocol-specific attributes introduced by the
  CDDL extension, including their semantics and how they relate to the
  underlying protocol operations.

<!-- LC: Should we consider adding an appendix showing the whole process to
create a fictitious new protocol? It may be of help to implementors. -->

# Registered Protocol Mappings

This section defines the protocol mappings registered by this document.

## BLE {#ble-pm}

The BLE protocol mapping allows SDF models to specify how properties and events
SHOULD be accessed using Bluetooth Low Energy (BLE) protocol {{BLE53}}. The
mapping includes details such as service IDs and characteristic IDs that are
used to access the corresponding SDF affordances.

### Properties

For `sdfProperty`, the BLE protocol mapping structure is defined as follows:

~~~ cddl
{::include cddl/ble-protocol-map.cddl}
~~~
{: #blemap1 title="CDDL definition for BLE Protocol Mapping for sdfProperty"}

Where:

- `serviceID` is the BLE service ID that corresponds to the SDF property.
- `characteristicID` is the BLE characteristic ID that corresponds to the SDF property.

For example, a BLE protocol mapping for a temperature property:

<!-- LC: I noticed that the UUIDs are too similar (only one character is
different); this may lead to confusion, e.g., implementors may think they should
use the same UUID for serviceID and characteristicID if they misread. I
recommend making the UUIDs sufficiently different (throughout all the examles). -->

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

For a temperature property that has different mappings for read and write operations,
here is an example of the BLE protocol mapping:

~~~ json
{
  "sdfProperty": {
    "temperature": {
      "sdfProtocolMap": {
        "ble": {
          "read": {
            "serviceID": "12345678-1234-5678-1234-56789abcdef4",
            "characteristicID": "12345678-1234-5678-1234-56789abcdef5"
          },
          "write": {
            "serviceID": "12345678-1234-5678-1234-56789abcdef4",
            "characteristicID": "12345678-1234-5678-1234-56789abcdef6"
          }
        }
      }
    }
  }
}
~~~

### Events

For `sdfEvent`s, the BLE protocol mapping structure is similar to
`sdfProperties`, but it MUST include additional attributes such as the `type` of
the event.

~~~ cddl
{::include cddl/ble-event-map.cddl}
~~~
{: #blemap2 title="BLE Protocol Mapping for sdfEvents"}

Where:

- `type` specifies the type of BLE event, such as "gatt" for GATT events,
  "advertisements" for advertisement events, or "connection_events" for
  connection-related events.
- `serviceID` and `characteristicID` are optional attributes that are
  specified if the type is "gatt".

<!-- LC: Is there a way to make serviceID and characteristicID mandatory only if
the type is gatt? The current solution allows a connection event to have a
serviceID, or characteristicID, or both. -->

For example, a BLE event mapping for a heart rate measurement event:

~~~ json
{
  "sdfEvent": {
    "heartRate": {
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
~~~

Here is an example of an `isPresent` event using BLE advertisements:

~~~ json
{
  "sdfEvent": {
    "isPresent": {
      "sdfProtocolMap": {
        "ble": {
          "type": "advertisements"
        }
      }
    }
  }
}
~~~

## Zigbee {#zigbee-pm}

The Zigbee protocol mapping allows SDF models to specify how properties,
actions, and events should be accessed using the Zigbee protocol {{Zigbee30}}.
The mapping includes details such as cluster IDs and attribute IDs that are used
to access the corresponding SDF affordances.

### Properties

An `sdfProperties` is mapped to Zigbee cluster attributes. The Zigbee property
protocol mapping structure is defined as follows:

~~~ cddl
{::include cddl/zigbee-protocol-map.cddl}
~~~
{: #zigmap1 title="CDDL definition for Zigbee Protocol Mapping for sdfProperty"}

Where:

- `endpointID` is the Zigbee endpoint ID that corresponds to the SDF property.
- `clusterID` is the Zigbee cluster ID that corresponds to the SDF property.
- `attributeID` is the Zigbee attribute ID that corresponds to the SDF property.
- `attributeType` is the Zigbee data type of the attribute.
- `manufacturerCode` is the Zigbee manufacturer code of the attribute (optional).

For example, a Zigbee protocol mapping for a temperature property may look as
follows:

~~~ json
{
  "sdfProperty": {
    "temperature": {
      "sdfProtocolMap": {
        "zigbee": {
          "endpointID": 1,
          "clusterID": 1026, // 0x0402
          "attributeID": 0, // 0x0000
          "attributeType": 41 // 0x29
        }
      }
    }
  }
}
~~~

### Events

An `sdfEvents` is mapped to Zigbee cluster attribute reporting. The Zigbee event
protocol mapping structure is defined as follows:

~~~ cddl
{::include cddl/zigbee-event-map.cddl}
~~~
{: #zigmap-event title="CDDL definition for Zigbee Protocol Mapping for sdfEvents"}

Where:

- `endpointID` is the Zigbee endpoint ID that corresponds to the SDF event.
- `clusterID` is the Zigbee cluster ID that corresponds to the SDF event.
- `attributeID` is the Zigbee attribute ID that corresponds to the SDF event.
- `attributeType` is the Zigbee data type of the attribute.
- `manufacturerCode` is the Zigbee manufacturer code of the attribute (optional).


For example, a Zigbee event mapping for a temperature change report:

~~~ json
{
  "sdfEvent": {
    "temperatureChange": {
      "sdfProtocolMap": {
        "zigbee": {
          "endpointID": 1,
          "clusterID": 1026, // 0x0402
          "attributeID": 0, // 0x0000
          "attributeType": 41 // 0x29
        }
      }
    }
  }
}
~~~


### Actions

An `sdfAction` SHOULD be mapped to Zigbee cluster commands. The Zigbee protocol
mapping structure for actions is defined as follows:

~~~ cddl
{::include cddl/zigbee-action-map.cddl}
~~~
{: #zigmap2 title="CDDL definition for Zigbee Protocol Mapping for sdfAction"}

Where:

- `endpointID` is the Zigbee endpoint ID that corresponds to the SDF action.
- `clusterID` is the Zigbee cluster ID that corresponds to the SDF action.
- `commandID` is the Zigbee command ID that corresponds to the SDF action.
- `manufacturerCode` is the Zigbee manufacturer code of the command (optional).

For example, a Zigbee protocol mapping to set a temperature:

~~~ json
{
  "sdfAction": {
    "setTemperature": {
      "sdfProtocolMap": {
        "zigbee": {
          "endpointID": 1,
          "clusterID": 1026, // 0x0402
          "commandID": 0 // 0x0000
        }
      }
    }
  }
}
~~~

# SCIM SDF Extension {#scim-sdf-extension}

While SDF provides a way to describe a device class and SCIM defines a device
instance, a method is needed to associate a mapping between an instance of a
device and its associated SDF models. To accomplish this, This document defines
a SCIM extension that MAY be used in conjunction with
{{!I-D.ietf-scim-device-model}} in {{scim-sdf-extension-schema}}. Implementation
of this SCIM extension is OPTIONAL and independent of the protocol mapping
functionality defined in the rest of this document. The SCIM schema attributes
used here are described in Section 7 of {{!RFC7643}}.

~~~
{::include generated/scim/scim-sdf-extension.json.folded}
~~~
{: #scim-sdf-extension-schema title="SCIM SDF Extension Schema"}

Here is an example SCIM device schema extension with SDF models:

~~~ json
{
    "schemas": [
        "urn:ietf:params:scim:schemas:core:2.0:Device",
        "urn:ietf:params:scim:schemas:extension:sdf:2.0:Device"
    ],
    "id": "e9e30dba-f08f-4109-8486-d5c6a3316111",
    "displayName": "Heart Monitor",
    "active": true,
    "urn:ietf:params:scim:schemas:extension:sdf:2.0:Device": {
        "sdf": [
            "https://example.com/thermometer#/sdfThing/thermometer",
            "https://example.com/heartrate#/sdfObject/healthsensor"
        ]
    }
}
~~~

An SDF model MUST be referenced with the `sdf` keyword inside the SCIM device
schema as described in {{!I-D.ietf-scim-device-model}}.

# Security Considerations

The security considerations of {{-sdf}} apply to this document as well.

Each protocol mapped using this mechanism has its own security model.
The protocol mapping mechanism defined in this document does not provide
additional security beyond what is offered by the underlying protocols.
Implementations MUST ensure that appropriate protocol-level security
mechanisms are employed when accessing affordances through the mapped
protocol operations.

# IANA Considerations

This section provides guidance to the Internet Assigned Numbers Authority
(IANA) regarding registration of values related to this document,
in accordance with {{!RFC8126}}.

## Protocol Mapping {#iana-prot-map}

IANA is requested to create a new registry called "SDF Protocol Mapping".

The registration policy for this registry is "Specification Required" as
defined in Section 4.6 of {{!RFC8126}}.

The registry must contain the following attributes:

- Protocol map name, as per `sdfProtocolMap`
- Protocol name
- Description
- Reference of the specification describing the protocol mapping.

The specification requirements for a registration request are
defined in {{protocol-registration}}.

The designated expert(s) SHOULD verify that the protocol map name is appropriate and not likely to cause confusion with existing entries.

The registrant of an existing entry may request updates to that entry, subject to the same expert review.
They should verify that updates preserve backward compatibility with deployed implementations, or if breaking changes are necessary, consider whether a new registry entry is more appropriate.

The following protocol mappings are described in this document:

| Protocol map | Protocol Name               | Description                                 | Reference       |
|--------------|-----------------------------|---------------------------------------------|-----------------|
| ble          | Bluetooth Low Energy (BLE)  | Protocol mapping for BLE devices            | This document   |
| zigbee       | Zigbee                      | Protocol mapping for Zigbee devices         | This document   |
{: #protmap-reg title="Protocol Mapping Registry"}

## SCIM Device Schema SDF Extension

IANA is requested to create the following extensions in the SCIM
Server-Related Schema URIs registry as described in {{scim-sdf-extension}}:

| URN | Description | Resource Type | Reference |
|-----|-------------|-----------|-----------|
| urn:ietf:params:scim: schemas:extension: sdf:2.0:Device | SDF Extension | Device | This memo, [](#scim-sdf-extension) |


--- back

# CDDL Definition

This appendix contains the combined CDDL definitions for the SDF protocol mappings.

~~~ cddl
<CODE BEGINS> file "sdf-protocol-map.cddl"
{::include generated/combined.cddl.folded}
<CODE ENDS>
~~~

# OpenAPI Definition

<!-- LC: Maybe we need some text to explain why all of a sudden there is some
OpenAPI specifications. -->

The following non-normative model is provided for convenience of the implementor.

~~~~~~
<CODE BEGINS> file "ProtocolMap.yaml"
{::include generated/openapi/ProtocolMap.yaml.folded}
<CODE ENDS>
~~~~~~
{: #protocolmapmodel}

## Protocol map for BLE

~~~~~
<CODE BEGINS> file "ProtocolMap-BLE.yaml"
{::include generated/openapi/ProtocolMap-BLE.yaml.folded}
<CODE ENDS>
~~~~~
{: #protocolmapble}

## Protocol map for Zigbee

~~~~~
<CODE BEGINS> file "ProtocolMap-Zigbee.yaml"
{::include generated/openapi/ProtocolMap-Zigbee.yaml.folded}
<CODE ENDS>
~~~~~
{: #protocolmapzigbee}

# Acknowledgements
{:numbered="false"}

<!-- LC: We need to add all the names of the ASDF WG that contributed with discussions, reviews, etc. -->

This document relies on SDF models described in {{-sdf}}, as such, we are grateful to the authors of this document for putting their time and effort into defining SDF in depth, allowing us to make use of it. The authors would also like to thank the ASDF working group for their excellent feedback and steering of the document.
