exception Bad_token

exception Bad_payload

(* ------------------------------- *)
(* ---------- Algorithm ---------- *)

(* IMPROVEME: add other algorithm *)
type algorithm =
  | HS256 of string (* the argument is the secret key *)
  | Unknown

let fn_of_algorithm = function
  | HS256 x -> Cryptokit.MAC.hmac_sha256 x
  | Unknown -> Cryptokit.MAC.hmac_sha256 ""

let string_of_algorithm = function
  | HS256 x -> "HS256"
  | Unknown -> ""

let algorithm_of_string = function
  | "HS256" -> HS256 ""
  | _       -> Unknown
(* ---------- Algorithm ---------- *)
(* ------------------------------- *)


(* ---------------------------- *)
(* ---------- Header ---------- *)

type header =
{
  alg : algorithm ;
  typ : string ; (* IMPROVEME: Need a sum type *)
}

let header_of_algorithm_and_typ alg typ = { alg ; typ }

(* ------- *)
(* getters *)

let algorithm_of_header h = h.alg

let typ_of_header h = h.typ

(* getters *)
(* ------- *)

let json_of_header header =
  `Assoc
  [
    ("alg", `String (string_of_algorithm (algorithm_of_header header))) ;
    ("typ", `String (typ_of_header header))
  ]

let string_of_header header =
  let json = json_of_header header in Yojson.Basic.to_string json

let header_of_json json =
  let alg =
    json |> Yojson.Basic.Util.member "alg" |> Yojson.Basic.Util.to_string
  in
  let typ =
    json |> Yojson.Basic.Util.member "typ" |> Yojson.Basic.Util.to_string
  in
  { alg = algorithm_of_string alg ; typ }

let header_of_string str =
  header_of_json (Yojson.Basic.from_string str)

(* ----------- Header ---------- *)
(* ----------------------------- *)

(* ---------------------------- *)
(* ----------- Claim ---------- *)

type claim         = string

let claim c        = c

let string_of_claim c = c

(* ------------- *)
(* Common claims *)

(* Issuer: identifies principal that issued the JWT *)
let iss            = "iss"

(* Subject: identifies the subject of the JWT *)
let sub            = "sub"

(* Audience: The "aud" (audience) claim identifies the recipients that the JWT
 * is intended for. Each principal intended to process the JWT MUST identify
 * itself with a value in the audience claim. If the principal processing the
 * claim does not identify itself with a value in the aud claim when this claim
 * is present, then the JWT MUST be rejected. *)
let aud            = "aud"

(* Expiration time: The "exp" (expiration time) claim identifies the expiration
 * time on or after which the JWT MUST NOT be accepted for processing. *)
let exp            = "exp"

(* Not before: Similarly, the not-before time claim identifies the time on which
 * the JWT will start to be accepted for processing. *)
let nbf            = "nbf"

(* Issued at: The "iat" (issued at) claim identifies the time at which the JWT
 * was issued.
 *)
let iat            = "iat"

(* JWT ID: case sensitive unique identifier of the token even among different
 * issuers.
 *)
let jti            = "jti"

(* Token type *)
let typ            = "typ"

(* Content type: This claim should always be JWT *)
let ctyp           = "ctyp"

(* Message authentication code algorithm (alg) - The issuer can freely set an
 * algorithm to verify the signature on the token. However, some asymmetrical
 * algorithms pose security concerns.
 *)
let alg            = "alg"

(* Common claims *)
(* ------------- *)

(* ------------------------- *)
(* Defined in OpenID Connect *)

(* Time when the End-User authentication occurred. Its value is a JSON number
 * representing the number of seconds from 1970-01-01T0:0:0Z as measured in UTC
 * until the date/time.
 *)
let auth_time      = "auth_time"

(* String value used to associate a Client session with an ID Token, and to
 * mitigate replay attacks. The value is passed through unmodified from the
 * Authentication Request to the ID Token. If present in the ID Token, Clients
 * MUST verify that the nonce Claim Value is equal to the value of the nonce
 * parameter sent in the Authentication Request. If present in the
 * Authentication Request, Authorization Servers MUST include a nonce Claim in
 * the ID Token with the Claim Value being the nonce value sent in the
 * Authentication Request. Authorization Servers SHOULD perform no other
 * processing on nonce values used. The nonce value is a case sensitive string.
 *)
let nonce          = "nonce"

let acr            = "acr"

let amr            = "amr"

let azp            = "azp"

(* Defined in OpenID Connect *)
(* ------------------------- *)

(* ----------- Claim ---------- *)
(* ---------------------------- *)

(* ------------------------------ *)
(* ----------- Payload ---------- *)

(* The payload a list of claim. The first component is the claim identifier and
 * the second is the value.
 *)
type payload = (claim * string) list

let empty_payload = []

let add_claim claim value payload =
  (claim, value) :: payload

let find_claim claim payload =
  let (_, value) =
    List.find (fun (c, v) -> (string_of_claim c) = (string_of_claim claim)) payload
  in
  value

let iter f p = List.iter f p

let map f p = List.map f p

let payload_of_json json =
  List.map
    (fun x -> match x with
    | (claim, `String value) -> (claim, value)
    | (claim, `Int value) -> (claim, string_of_int value)
    | _ -> raise Bad_payload
    )
    (Yojson.Basic.Util.to_assoc json)

let payload_of_string str =
  payload_of_json (Yojson.Basic.from_string str)

let json_of_payload payload =
  let members =
    map
      (fun (claim, value) -> ((string_of_claim claim), `String value))
      payload
  in
  `Assoc members

let string_of_payload payload =
  Yojson.Basic.to_string (json_of_payload payload)

(* ----------- Payload ---------- *)
(* ------------------------------ *)

(* -------------------------------- *)
(* ----------- JWT type ----------- *)

type t =
{
  header : header ;
  payload : payload ;
  signature : string
}

let t_of_header_and_payload header payload =
  let b64_header = (B64.encode (string_of_header header)) in
  let b64_payload = (B64.encode (string_of_payload payload)) in
  let algo = fn_of_algorithm (algorithm_of_header header) in
  let unsigned_token = b64_header ^ "." ^ b64_payload in
  let signature =
    Cryptokit.hash_string algo unsigned_token
  in
  { header ; payload ; signature }
(* ------- *)
(* getters *)

let header_of_t t = t.header

let payload_of_t t = t.payload

let signature_of_t t = t.signature

(* getters *)
(* ------- *)

let token_of_t t =
  let b64_header = (B64.encode (string_of_header (header_of_t t))) in
  let b64_payload = (B64.encode (string_of_payload (payload_of_t t))) in
  let b64_signature = (B64.encode (signature_of_t t)) in
  b64_header ^ "." ^ b64_payload ^ "." ^ b64_signature

let t_of_token token =
  try
    let token_splitted = Re_str.split_delim (Re_str.regexp_string ".") token in
    match token_splitted with
    | [ header_encoded ; payload_encoded ; signature_encoded ] ->
        let header = header_of_string (B64.decode header_encoded) in
        let payload = payload_of_string (B64.decode payload_encoded) in
        let signature = B64.decode signature_encoded in
        { header ; payload ; signature }
    | _ -> raise Bad_token
  with _ -> raise Bad_token

(* ----------- JWT type ----------- *)
(* -------------------------------- *)
