(*
 * Configuration variables and utility functions
 *)
val maximumFileSize = 18*1024*1024 (* 18 MB *)
val thumbsPerPage = 16

fun mapDml f l =
    case l of
        [] => return ()
      | x :: xs => dml (f x); mapDml f xs

fun range ( n : int) (m : int) : list int =
    let
        val operator = if n < m then plus else minus
        fun f n m a = if eq n m then List.rev a else f (operator n 1) m (n :: a)
    in
        f n m []
    end

(*
 * Sql database stuff
 *)

sequence s

table images : {
      Id : int, Title : string,
      MimeType : string, Image : blob, Thumbnail : blob
} PRIMARY KEY Id

table tags : {
      Id : int, Tag : string
} CONSTRAINT Id FOREIGN KEY Id REFERENCES images(Id)



(*
 * CSS stuff
 *)

style header
style wrapper
style sidebar
style content
style thumb
style pageNumbers

val cssString = "
.header h1 {
  text-align: center;
}
.header a {
  text-decoration: none;
}

.wrapper {
    display: flex;
}
.sidebar {
  float: left;
  padding: 10px;
  width: 150px;
}
.sidebar a {
  text-decoration: none;
  font-size: 15px;
}
.content {
  /* margin-left: 180px;*/
  /* equal to sidebar width + 2*padding. Replaced by flex */
}

span.thumb {
  height: 200px;
  width: 200px;
  display: inline-block;
  float: left;
  text-align: center;
  vertical-align: middle;
}

.page-numbers {
  clear: both;
  text-align: center;
}
.page-numbers span {
  margin: 0px 3px;
  padding: 2px 6px;
  font-weight: normal;
  border: 1px solid;
  border-color: pink;
}
.page-numbers a {
  text-decoration: none;
}

div.sidebar {
  border-width: thick;
  border-style: groove;
  border-color: gold;
}
div.header {
  border-width: thick;
  border-style: groove;
  border-color: gold;  
}
div.content {
  border-width: thick;
  border-style: groove;
  border-color: gold;
  width: 100%;
}
div.page-numbers {
  border-width: thick;
  border-style: groove;
  border-color: gold;
  padding: 5px;
}
"

fun css () =
    returnBlob (textBlob cssString) (blessMime "text/css")



(*
 * Image/Thumbnail blobs
 *)

fun image id =
    r <- oneRow (SELECT images.Image, images.MimeType
                 FROM images
                 WHERE images.Id={[id]});
    returnBlob r.Images.Image (blessMime r.Images.MimeType)

fun thumbnail id =
    r <- oneRow (SELECT images.Thumbnail
                 FROM images
                 WHERE images.Id={[id]});
    returnBlob r.Images.Thumbnail (blessMime "image/jpeg")
    


(*
 * Query parsing
 *)

type query = { Positive : list string, Negative : list string }

fun parseList (s : string) (a : list string) : list string =
    case String.split s #"," of
        Some (x, xs) => parseList xs (String.trim x :: a)
      | None         => ((String.trim s) :: a)

fun partition (p : string -> bool) : list string -> query =
    List.foldr
        (fn x a => if p x then { Positive = a.Positive, Negative = x :: a.Negative }
                   else { Positive = x :: a.Positive, Negative = a.Negative })
        { Positive = [], Negative = [] }

fun parseQuery (s : string) : query =
    let val x = partition (fn s' => String.isPrefix {Full = s', Prefix = "-"}) (parseList s []) in
        { Positive = x.Positive, Negative = (List.mp (fn s' => strsuffix s' 1) x.Negative) } end




(*
 * Dynamic query generation
 *)

type tag_query = sql_query [] [] [] [Id = int]

fun positiveCondition (tag : string) (q : tag_query) : tag_query =
    (SELECT I.Id AS Id
     FROM ({{q}}) AS I
       JOIN tags ON tags.Id = I.Id AND tags.Tag = {[tag]})

fun negativeCondition (tag : string) (q : tag_query) : tag_query =
    (SELECT I.Id AS Id
     FROM ({{q}}) AS I
       LEFT JOIN tags ON tags.Id = I.Id AND tags.Tag = {[tag]}
     WHERE tags.Tag IS NULL)

fun withConditions (q : query) : tag_query =
    List.foldl negativeCondition
               (List.foldl positiveCondition
                           (SELECT images.Id AS Id FROM images)
                           q.Positive)
               q.Negative

fun searchQuery queryString =
    if eq queryString "" then
        (SELECT images.Id AS Id FROM images)
    else
        withConditions (parseQuery queryString)



(*
 * Web pages
 *)

fun template (pageTitle : string) sidebarBody contentBody footerBody =
    return <xml>
      <head>
        <title>{[pageTitle]}</title>
        <link rel="stylesheet" type="text/css" href={url (css ())}/>
      </head>
      <body>
        <div class={header}>
          <a href={url (main ())}><h1>Gallury</h1></a>
        </div>
        <div class={wrapper}>
          <div class={sidebar}>{sidebarBody}</div>
          <div class={content}>{contentBody}</div>
        </div>
        <div class={pageNumbers}>{footerBody}</div>
    </body></xml>

and post () =
    let
        fun submitPost upload =
            (* This procedure does all the necessary checks on uploaded content *)
            if blobSize (fileData upload.File) > maximumFileSize then
                return <xml>Whoa!  That one's too big.</xml>
            else
                case checkMime (fileMimeType upload.File) of
                    None => return <xml>Whoa!  I'm not touching that.</xml>
                  | Some _ =>
                    case Thumbnailer.thumbnail upload.File of
                        None => return <xml><body>
                          <h1>At least you tried!</h1>
                          <p>Could not generate thumbnail (invalid image)</p>
                          <a href={url (main ())}>home</a>
                        </body></xml>
                      | Some thumb => uploadPost upload thumb
        and uploadPost upload thumb =
            (* This thumbnails and stores the uploaded, verified image into the database *)
            let
                val title = case fileName upload.File of
                                None => "Untitled"
                              | Some t => t
            in
                id <- nextval s;
                dml (INSERT INTO images (Id, Title, MimeType, Image, Thumbnail)
                     VALUES ({[id]}, {[title]},
                         {[fileMimeType upload.File]}, {[fileData upload.File]}, {[thumb]}));
                return <xml><body>
                  <h1>Uploaded Successfully!</h1>
                  <a href={url (page id)}>click here</a>
                </body></xml>
            end
    in
        template "Post"
                 <xml/>
                 <xml>
                   <form>
                     <upload{#File}/>
                     <submit action={submitPost}/>
                   </form>
                 </xml>
                 <xml/>
    end
    
and page id =
    let
        fun makeLi row = <xml><li>
          <a href={url (search row.Tags.Tag 0)}>{[row.Tags.Tag]}</a>
        </li></xml>
        fun addTags id queryString =
            let
                val tagList = parseQuery queryString.Tags
            in
                mapDml (fn t => (INSERT INTO tags (Id, Tag) VALUES ({[id]}, {[t]})))
                       tagList.Positive;
                mapDml (fn t => (DELETE FROM tags WHERE Id = {[id]} AND Tag = {[t]}))
                       tagList.Negative;
                redirect (url (page id))
            end
    in
        title <- oneRow (SELECT images.Title FROM images WHERE images.Id={[id]});
        tagLis <- queryX (SELECT tags.Tag FROM tags WHERE tags.Id={[id]} ORDER BY tags.Tag)
                         makeLi;
        template ("Page: " ^ title.Images.Title)
                 <xml>
                   <ul>{tagLis}</ul>
                   Add tags:
                   <form>
                     <textbox{#Tags} size=12/>
                     <submit action={addTags id} style={STYLE "display: none"}/>
                   </form>
                   <hr/>
                   <a href={url (post ())}>Upload</a>
                 </xml>
                 <xml>
                   <img src={url (image id)} style={STYLE "max-width: 100%"}/>
                 </xml>
                 <xml/>
    end

and search queryString pageNumber =
    let
        val query = (SELECT I.Id AS Id
                     FROM ({{searchQuery queryString}}) AS I
                     ORDER BY Id DESC
                     LIMIT {thumbsPerPage} OFFSET {thumbsPerPage * pageNumber})
        val countQuery = (SELECT COUNT( * ) AS N
                          FROM ({{searchQuery queryString}}) AS I)
        fun roundUp pages = if pages % thumbsPerPage = 0 then
                                pages / thumbsPerPage
                            else pages / thumbsPerPage + 1
        fun submitSearch query = redirect (url (search query.Query 0))
        fun makeThumbnail row =
            <xml><span class={thumb}>
              <a href={url (page row.Id)}>
                <img src={url (thumbnail row.Id)}/></a>
            </span></xml>
            fun generatePageNumbers pages =
                List.mapX (fn n =>
                              if eq n pageNumber then
                                  <xml><span>{[pageNumber]}</span></xml>
                              else
                                  <xml><span><a href={url (search queryString n)}>{[n]}</a></span></xml>)
                          (List.filter (fn n => n >= 0) (range 0 pages))
    in
        thumbnails <- queryX query makeThumbnail;
        pages <- oneRow countQuery;
        template "Search"
                 <xml>
                   <form>
                     <textbox{#Query} size=12 value={queryString}/>
                     <submit action={submitSearch} style={STYLE "display: none"}/>
                   </form>
                   <hr/>
                   <a href={url (post ())}>Upload</a>
                 </xml>
                 thumbnails
                 (generatePageNumbers (roundUp (pages.N)))
    end

and main () = search "" 0
