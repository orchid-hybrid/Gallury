val css : unit -> transaction page
val image : int -> transaction page
val thumbnail : int -> transaction page

val post : unit -> transaction page
val page : int -> transaction page
val search : string -> int -> transaction page

val main : unit -> transaction page
