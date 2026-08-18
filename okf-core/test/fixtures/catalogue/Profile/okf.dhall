{ Cardinality = < Any | List | Scalar >
, FieldCondition = { field : Text, hasValue : List Text }
, FieldFormat =
    < Actor
    | Boolean
    | Date
    | DocumentHandle : Text
    | HumanActor
    | Integer
    | NonNegativeInteger
    | Rfc3339Utc
    | Uri
    | UriWithScheme : Text
    >
, FieldRule =
    { allowedValues : List Text
    , cardinality : < Any | List | Scalar >
    , description : Optional Text
    , elementFields :
        Optional
          { optional :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          , recommended :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          , required :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          }
    , field : Text
    , format :
        Optional
          < Actor
          | Boolean
          | Date
          | DocumentHandle : Text
          | HumanActor
          | Integer
          | NonNegativeInteger
          | Rfc3339Utc
          | Uri
          | UriWithScheme : Text
          >
    , objectFields :
        Optional
          { optional :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          , recommended :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          , required :
              List
                { allowedValues : List Text
                , cardinality : < Any | List | Scalar >
                , description : Optional Text
                , field : Text
                , format :
                    Optional
                      < Actor
                      | Boolean
                      | Date
                      | DocumentHandle : Text
                      | HumanActor
                      | Integer
                      | NonNegativeInteger
                      | Rfc3339Utc
                      | Uri
                      | UriWithScheme : Text
                      >
                , path :
                    Optional
                      { allowSelf : Bool, externalUriSchemes : List Text }
                , when : Optional { field : Text, hasValue : List Text }
                }
          }
    , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
    , reference :
        Optional
          { allowSelf : Bool
          , externalUriSchemes : List Text
          , localPrefix : Text
          }
    , when : Optional { field : Text, hasValue : List Text }
    }
, FrontmatterRules =
    { optional :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , elementFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , reference :
              Optional
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when : Optional { field : Text, hasValue : List Text }
          }
    , recommended :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , elementFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , reference :
              Optional
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when : Optional { field : Text, hasValue : List Text }
          }
    , required :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , elementFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields :
              Optional
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , reference :
              Optional
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when : Optional { field : Text, hasValue : List Text }
          }
    }
, HandleReferenceRule =
    { allowSelf : Bool, externalUriSchemes : List Text, localPrefix : Text }
, NestedFieldRule =
    { allowedValues : List Text
    , cardinality : < Any | List | Scalar >
    , description : Optional Text
    , field : Text
    , format :
        Optional
          < Actor
          | Boolean
          | Date
          | DocumentHandle : Text
          | HumanActor
          | Integer
          | NonNegativeInteger
          | Rfc3339Utc
          | Uri
          | UriWithScheme : Text
          >
    , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
    , when : Optional { field : Text, hasValue : List Text }
    }
, NestedRules =
    { optional :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , when : Optional { field : Text, hasValue : List Text }
          }
    , recommended :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , when : Optional { field : Text, hasValue : List Text }
          }
    , required :
        List
          { allowedValues : List Text
          , cardinality : < Any | List | Scalar >
          , description : Optional Text
          , field : Text
          , format :
              Optional
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
          , when : Optional { field : Text, hasValue : List Text }
          }
    }
, PathReferenceRule = { allowSelf : Bool, externalUriSchemes : List Text }
, Profile =
    { allowUnknownFields : Bool
    , allowUnknownTypes : Bool
    , description : Optional Text
    , frontmatter :
        { optional :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , recommended :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , required :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        }
    , idField : Optional Text
    , name : Text
    , okfVersion : Text
    , requireBundleVersion : Optional Text
    , types :
        List
          { description : Optional Text
          , frontmatter :
              { optional :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , elementFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , objectFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , reference :
                        Optional
                          { allowSelf : Bool
                          , externalUriSchemes : List Text
                          , localPrefix : Text
                          }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , recommended :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , elementFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , objectFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , reference :
                        Optional
                          { allowSelf : Bool
                          , externalUriSchemes : List Text
                          , localPrefix : Text
                          }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , required :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , elementFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , objectFields :
                        Optional
                          { optional :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , recommended :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          , required :
                              List
                                { allowedValues : List Text
                                , cardinality : < Any | List | Scalar >
                                , description : Optional Text
                                , field : Text
                                , format :
                                    Optional
                                      < Actor
                                      | Boolean
                                      | Date
                                      | DocumentHandle : Text
                                      | HumanActor
                                      | Integer
                                      | NonNegativeInteger
                                      | Rfc3339Utc
                                      | Uri
                                      | UriWithScheme : Text
                                      >
                                , path :
                                    Optional
                                      { allowSelf : Bool
                                      , externalUriSchemes : List Text
                                      }
                                , when :
                                    Optional
                                      { field : Text, hasValue : List Text }
                                }
                          }
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , reference :
                        Optional
                          { allowSelf : Bool
                          , externalUriSchemes : List Text
                          , localPrefix : Text
                          }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              }
          , idPrefix : Optional Text
          , pathPattern : Optional Text
          , requireSchemaSection : Bool
          , resourceScheme : Optional Text
          , schemaColumns : List Text
          , type : Text
          }
    }
, TypeRule =
    { description : Optional Text
    , frontmatter :
        { optional :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , recommended :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , required :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        }
    , idPrefix : Optional Text
    , pathPattern : Optional Text
    , requireSchemaSection : Bool
    , resourceScheme : Optional Text
    , schemaColumns : List Text
    , type : Text
    }
, defaults =
  { FieldRule =
    { Type =
        { allowedValues : List Text
        , cardinality : < Any | List | Scalar >
        , description : Optional Text
        , elementFields :
            Optional
              { optional :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , recommended :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , required :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              }
        , field : Text
        , format :
            Optional
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >
        , objectFields :
            Optional
              { optional :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , recommended :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              , required :
                  List
                    { allowedValues : List Text
                    , cardinality : < Any | List | Scalar >
                    , description : Optional Text
                    , field : Text
                    , format :
                        Optional
                          < Actor
                          | Boolean
                          | Date
                          | DocumentHandle : Text
                          | HumanActor
                          | Integer
                          | NonNegativeInteger
                          | Rfc3339Utc
                          | Uri
                          | UriWithScheme : Text
                          >
                    , path :
                        Optional
                          { allowSelf : Bool, externalUriSchemes : List Text }
                    , when : Optional { field : Text, hasValue : List Text }
                    }
              }
        , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
        , reference :
            Optional
              { allowSelf : Bool
              , externalUriSchemes : List Text
              , localPrefix : Text
              }
        , when : Optional { field : Text, hasValue : List Text }
        }
    , default =
      { allowedValues = [] : List Text
      , cardinality = < Any | List | Scalar >.Any
      , description = None Text
      , elementFields =
          None
            { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
      , format =
          None
            < Actor
            | Boolean
            | Date
            | DocumentHandle : Text
            | HumanActor
            | Integer
            | NonNegativeInteger
            | Rfc3339Utc
            | Uri
            | UriWithScheme : Text
            >
      , objectFields =
          None
            { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
      , path = None { allowSelf : Bool, externalUriSchemes : List Text }
      , reference =
          None
            { allowSelf : Bool
            , externalUriSchemes : List Text
            , localPrefix : Text
            }
      , when = None { field : Text, hasValue : List Text }
      }
    }
  , FrontmatterRules =
    { Type =
        { optional :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , recommended :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , required :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , elementFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , objectFields :
                  Optional
                    { optional :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , recommended :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    , required :
                        List
                          { allowedValues : List Text
                          , cardinality : < Any | List | Scalar >
                          , description : Optional Text
                          , field : Text
                          , format :
                              Optional
                                < Actor
                                | Boolean
                                | Date
                                | DocumentHandle : Text
                                | HumanActor
                                | Integer
                                | NonNegativeInteger
                                | Rfc3339Utc
                                | Uri
                                | UriWithScheme : Text
                                >
                          , path :
                              Optional
                                { allowSelf : Bool
                                , externalUriSchemes : List Text
                                }
                          , when :
                              Optional { field : Text, hasValue : List Text }
                          }
                    }
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , reference :
                  Optional
                    { allowSelf : Bool
                    , externalUriSchemes : List Text
                    , localPrefix : Text
                    }
              , when : Optional { field : Text, hasValue : List Text }
              }
        }
    , default =
      { optional =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , elementFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , objectFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , reference :
                     Optional
                       { allowSelf : Bool
                       , externalUriSchemes : List Text
                       , localPrefix : Text
                       }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      , recommended =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , elementFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , objectFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , reference :
                     Optional
                       { allowSelf : Bool
                       , externalUriSchemes : List Text
                       , localPrefix : Text
                       }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      , required =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , elementFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , objectFields :
                     Optional
                       { optional :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , recommended :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       , required :
                           List
                             { allowedValues : List Text
                             , cardinality : < Any | List | Scalar >
                             , description : Optional Text
                             , field : Text
                             , format :
                                 Optional
                                   < Actor
                                   | Boolean
                                   | Date
                                   | DocumentHandle : Text
                                   | HumanActor
                                   | Integer
                                   | NonNegativeInteger
                                   | Rfc3339Utc
                                   | Uri
                                   | UriWithScheme : Text
                                   >
                             , path :
                                 Optional
                                   { allowSelf : Bool
                                   , externalUriSchemes : List Text
                                   }
                             , when :
                                 Optional { field : Text, hasValue : List Text }
                             }
                       }
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , reference :
                     Optional
                       { allowSelf : Bool
                       , externalUriSchemes : List Text
                       , localPrefix : Text
                       }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      }
    }
  , HandleReferenceRule =
    { Type =
        { allowSelf : Bool, externalUriSchemes : List Text, localPrefix : Text }
    , default = { allowSelf = False, externalUriSchemes = [] : List Text }
    }
  , NestedFieldRule =
    { Type =
        { allowedValues : List Text
        , cardinality : < Any | List | Scalar >
        , description : Optional Text
        , field : Text
        , format :
            Optional
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >
        , path : Optional { allowSelf : Bool, externalUriSchemes : List Text }
        , when : Optional { field : Text, hasValue : List Text }
        }
    , default =
      { allowedValues = [] : List Text
      , cardinality = < Any | List | Scalar >.Any
      , description = None Text
      , format =
          None
            < Actor
            | Boolean
            | Date
            | DocumentHandle : Text
            | HumanActor
            | Integer
            | NonNegativeInteger
            | Rfc3339Utc
            | Uri
            | UriWithScheme : Text
            >
      , path = None { allowSelf : Bool, externalUriSchemes : List Text }
      , when = None { field : Text, hasValue : List Text }
      }
    }
  , NestedRules =
    { Type =
        { optional :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , recommended :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , when : Optional { field : Text, hasValue : List Text }
              }
        , required :
            List
              { allowedValues : List Text
              , cardinality : < Any | List | Scalar >
              , description : Optional Text
              , field : Text
              , format :
                  Optional
                    < Actor
                    | Boolean
                    | Date
                    | DocumentHandle : Text
                    | HumanActor
                    | Integer
                    | NonNegativeInteger
                    | Rfc3339Utc
                    | Uri
                    | UriWithScheme : Text
                    >
              , path :
                  Optional { allowSelf : Bool, externalUriSchemes : List Text }
              , when : Optional { field : Text, hasValue : List Text }
              }
        }
    , default =
      { optional =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      , recommended =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      , required =
          [] : List
                 { allowedValues : List Text
                 , cardinality : < Any | List | Scalar >
                 , description : Optional Text
                 , field : Text
                 , format :
                     Optional
                       < Actor
                       | Boolean
                       | Date
                       | DocumentHandle : Text
                       | HumanActor
                       | Integer
                       | NonNegativeInteger
                       | Rfc3339Utc
                       | Uri
                       | UriWithScheme : Text
                       >
                 , path :
                     Optional
                       { allowSelf : Bool, externalUriSchemes : List Text }
                 , when : Optional { field : Text, hasValue : List Text }
                 }
      }
    }
  , PathReferenceRule =
    { Type = { allowSelf : Bool, externalUriSchemes : List Text }
    , default = { allowSelf = False, externalUriSchemes = [] : List Text }
    }
  , Profile =
    { Type =
        { allowUnknownFields : Bool
        , allowUnknownTypes : Bool
        , description : Optional Text
        , frontmatter :
            { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
        , idField : Optional Text
        , name : Text
        , okfVersion : Text
        , requireBundleVersion : Optional Text
        , types :
            List
              { description : Optional Text
              , frontmatter :
                  { optional :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , elementFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , objectFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , reference :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              , localPrefix : Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , recommended :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , elementFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , objectFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , reference :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              , localPrefix : Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , required :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , elementFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , objectFields :
                            Optional
                              { optional :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , recommended :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              , required :
                                  List
                                    { allowedValues : List Text
                                    , cardinality : < Any | List | Scalar >
                                    , description : Optional Text
                                    , field : Text
                                    , format :
                                        Optional
                                          < Actor
                                          | Boolean
                                          | Date
                                          | DocumentHandle : Text
                                          | HumanActor
                                          | Integer
                                          | NonNegativeInteger
                                          | Rfc3339Utc
                                          | Uri
                                          | UriWithScheme : Text
                                          >
                                    , path :
                                        Optional
                                          { allowSelf : Bool
                                          , externalUriSchemes : List Text
                                          }
                                    , when :
                                        Optional
                                          { field : Text, hasValue : List Text }
                                    }
                              }
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , reference :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              , localPrefix : Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  }
              , idPrefix : Optional Text
              , pathPattern : Optional Text
              , requireSchemaSection : Bool
              , resourceScheme : Optional Text
              , schemaColumns : List Text
              , type : Text
              }
        }
    , default =
      { allowUnknownFields = True
      , allowUnknownTypes = True
      , description = None Text
      , frontmatter =
        { optional =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        , recommended =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        , required =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        }
      , idField = None Text
      , okfVersion = "0.1"
      , requireBundleVersion = None Text
      , types =
          [] : List
                 { description : Optional Text
                 , frontmatter :
                     { optional :
                         List
                           { allowedValues : List Text
                           , cardinality : < Any | List | Scalar >
                           , description : Optional Text
                           , elementFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , field : Text
                           , format :
                               Optional
                                 < Actor
                                 | Boolean
                                 | Date
                                 | DocumentHandle : Text
                                 | HumanActor
                                 | Integer
                                 | NonNegativeInteger
                                 | Rfc3339Utc
                                 | Uri
                                 | UriWithScheme : Text
                                 >
                           , objectFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , path :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 }
                           , reference :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 , localPrefix : Text
                                 }
                           , when :
                               Optional { field : Text, hasValue : List Text }
                           }
                     , recommended :
                         List
                           { allowedValues : List Text
                           , cardinality : < Any | List | Scalar >
                           , description : Optional Text
                           , elementFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , field : Text
                           , format :
                               Optional
                                 < Actor
                                 | Boolean
                                 | Date
                                 | DocumentHandle : Text
                                 | HumanActor
                                 | Integer
                                 | NonNegativeInteger
                                 | Rfc3339Utc
                                 | Uri
                                 | UriWithScheme : Text
                                 >
                           , objectFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , path :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 }
                           , reference :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 , localPrefix : Text
                                 }
                           , when :
                               Optional { field : Text, hasValue : List Text }
                           }
                     , required :
                         List
                           { allowedValues : List Text
                           , cardinality : < Any | List | Scalar >
                           , description : Optional Text
                           , elementFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , field : Text
                           , format :
                               Optional
                                 < Actor
                                 | Boolean
                                 | Date
                                 | DocumentHandle : Text
                                 | HumanActor
                                 | Integer
                                 | NonNegativeInteger
                                 | Rfc3339Utc
                                 | Uri
                                 | UriWithScheme : Text
                                 >
                           , objectFields :
                               Optional
                                 { optional :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , recommended :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 , required :
                                     List
                                       { allowedValues : List Text
                                       , cardinality : < Any | List | Scalar >
                                       , description : Optional Text
                                       , field : Text
                                       , format :
                                           Optional
                                             < Actor
                                             | Boolean
                                             | Date
                                             | DocumentHandle : Text
                                             | HumanActor
                                             | Integer
                                             | NonNegativeInteger
                                             | Rfc3339Utc
                                             | Uri
                                             | UriWithScheme : Text
                                             >
                                       , path :
                                           Optional
                                             { allowSelf : Bool
                                             , externalUriSchemes : List Text
                                             }
                                       , when :
                                           Optional
                                             { field : Text
                                             , hasValue : List Text
                                             }
                                       }
                                 }
                           , path :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 }
                           , reference :
                               Optional
                                 { allowSelf : Bool
                                 , externalUriSchemes : List Text
                                 , localPrefix : Text
                                 }
                           , when :
                               Optional { field : Text, hasValue : List Text }
                           }
                     }
                 , idPrefix : Optional Text
                 , pathPattern : Optional Text
                 , requireSchemaSection : Bool
                 , resourceScheme : Optional Text
                 , schemaColumns : List Text
                 , type : Text
                 }
      }
    }
  , TypeRule =
    { Type =
        { description : Optional Text
        , frontmatter :
            { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , elementFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , objectFields :
                      Optional
                        { optional :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , recommended :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        , required :
                            List
                              { allowedValues : List Text
                              , cardinality : < Any | List | Scalar >
                              , description : Optional Text
                              , field : Text
                              , format :
                                  Optional
                                    < Actor
                                    | Boolean
                                    | Date
                                    | DocumentHandle : Text
                                    | HumanActor
                                    | Integer
                                    | NonNegativeInteger
                                    | Rfc3339Utc
                                    | Uri
                                    | UriWithScheme : Text
                                    >
                              , path :
                                  Optional
                                    { allowSelf : Bool
                                    , externalUriSchemes : List Text
                                    }
                              , when :
                                  Optional
                                    { field : Text, hasValue : List Text }
                              }
                        }
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , reference :
                      Optional
                        { allowSelf : Bool
                        , externalUriSchemes : List Text
                        , localPrefix : Text
                        }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
        , idPrefix : Optional Text
        , pathPattern : Optional Text
        , requireSchemaSection : Bool
        , resourceScheme : Optional Text
        , schemaColumns : List Text
        , type : Text
        }
    , default =
      { description = None Text
      , frontmatter =
        { optional =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        , recommended =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        , required =
            [] : List
                   { allowedValues : List Text
                   , cardinality : < Any | List | Scalar >
                   , description : Optional Text
                   , elementFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , field : Text
                   , format :
                       Optional
                         < Actor
                         | Boolean
                         | Date
                         | DocumentHandle : Text
                         | HumanActor
                         | Integer
                         | NonNegativeInteger
                         | Rfc3339Utc
                         | Uri
                         | UriWithScheme : Text
                         >
                   , objectFields :
                       Optional
                         { optional :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , recommended :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         , required :
                             List
                               { allowedValues : List Text
                               , cardinality : < Any | List | Scalar >
                               , description : Optional Text
                               , field : Text
                               , format :
                                   Optional
                                     < Actor
                                     | Boolean
                                     | Date
                                     | DocumentHandle : Text
                                     | HumanActor
                                     | Integer
                                     | NonNegativeInteger
                                     | Rfc3339Utc
                                     | Uri
                                     | UriWithScheme : Text
                                     >
                               , path :
                                   Optional
                                     { allowSelf : Bool
                                     , externalUriSchemes : List Text
                                     }
                               , when :
                                   Optional
                                     { field : Text, hasValue : List Text }
                               }
                         }
                   , path :
                       Optional
                         { allowSelf : Bool, externalUriSchemes : List Text }
                   , reference :
                       Optional
                         { allowSelf : Bool
                         , externalUriSchemes : List Text
                         , localPrefix : Text
                         }
                   , when : Optional { field : Text, hasValue : List Text }
                   }
        }
      , idPrefix = None Text
      , pathPattern = None Text
      , requireSchemaSection = False
      , resourceScheme = None Text
      , schemaColumns = [] : List Text
      }
    }
  }
, mk =
  { FieldRule =
    { actor =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Actor
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , boolean =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Boolean
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , bundlePath =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = Some
            { allowSelf = False, externalUriSchemes = [] : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , conditional =
        \ ( _
          : { allowedValues : List Text
            , cardinality : < Any | List | Scalar >
            , description : Optional Text
            , elementFields :
                Optional
                  { optional :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , recommended :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , required :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  }
            , field : Text
            , format :
                Optional
                  < Actor
                  | Boolean
                  | Date
                  | DocumentHandle : Text
                  | HumanActor
                  | Integer
                  | NonNegativeInteger
                  | Rfc3339Utc
                  | Uri
                  | UriWithScheme : Text
                  >
            , objectFields :
                Optional
                  { optional :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , recommended :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  , required :
                      List
                        { allowedValues : List Text
                        , cardinality : < Any | List | Scalar >
                        , description : Optional Text
                        , field : Text
                        , format :
                            Optional
                              < Actor
                              | Boolean
                              | Date
                              | DocumentHandle : Text
                              | HumanActor
                              | Integer
                              | NonNegativeInteger
                              | Rfc3339Utc
                              | Uri
                              | UriWithScheme : Text
                              >
                        , path :
                            Optional
                              { allowSelf : Bool
                              , externalUriSchemes : List Text
                              }
                        , when : Optional { field : Text, hasValue : List Text }
                        }
                  }
            , path :
                Optional { allowSelf : Bool, externalUriSchemes : List Text }
            , reference :
                Optional
                  { allowSelf : Bool
                  , externalUriSchemes : List Text
                  , localPrefix : Text
                  }
            , when : Optional { field : Text, hasValue : List Text }
            }
          ) ->
        \(_ : { field : Text, hasValue : List Text }) ->
          _@1
          with when = Some _
    , date =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Date
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , documentHandle =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format = Some
              ( < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >.DocumentHandle
                  _
              )
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , documented =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = Some _
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , enum =
        \(_ : Text) ->
        \(_ : List Text) ->
          { allowedValues = _
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , humanActor =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.HumanActor
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , integer =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Integer
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , list =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.List
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , localOrExternalPath =
        \(_ : Text) ->
        \(_ : List Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = Some { allowSelf = False, externalUriSchemes = _ }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , localOrExternalReference =
        \(_ : Text) ->
        \(_ : Text) ->
        \(_ : List Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@2
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference = Some
            { allowSelf = False, externalUriSchemes = _, localPrefix = _@1 }
          , when = None { field : Text, hasValue : List Text }
          }
    , localReference =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference = Some
            { allowSelf = False
            , externalUriSchemes = [] : List Text
            , localPrefix = _
            }
          , when = None { field : Text, hasValue : List Text }
          }
    , nonNegativeInteger =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.NonNegativeInteger
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , plain =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , record =
        \(_ : Text) ->
        \ ( _
          : { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
          ) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields = Some _
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , recordList =
        \(_ : Text) ->
        \ ( _
          : { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
          ) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.List
          , description = None Text
          , elementFields = Some _
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , recordOrList =
        \(_ : Text) ->
        \ ( _
          : { optional :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , recommended :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            , required :
                List
                  { allowedValues : List Text
                  , cardinality : < Any | List | Scalar >
                  , description : Optional Text
                  , field : Text
                  , format :
                      Optional
                        < Actor
                        | Boolean
                        | Date
                        | DocumentHandle : Text
                        | HumanActor
                        | Integer
                        | NonNegativeInteger
                        | Rfc3339Utc
                        | Uri
                        | UriWithScheme : Text
                        >
                  , path :
                      Optional
                        { allowSelf : Bool, externalUriSchemes : List Text }
                  , when : Optional { field : Text, hasValue : List Text }
                  }
            }
          ) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields = Some _
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields = Some _
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , rfc3339Utc =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Rfc3339Utc
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , scalar =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Scalar
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , uri =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Uri
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    , uriWithScheme =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , elementFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , field = _@1
          , format = Some
              ( < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >.UriWithScheme
                  _
              )
          , objectFields =
              None
                { optional :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , recommended :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                , required :
                    List
                      { allowedValues : List Text
                      , cardinality : < Any | List | Scalar >
                      , description : Optional Text
                      , field : Text
                      , format :
                          Optional
                            < Actor
                            | Boolean
                            | Date
                            | DocumentHandle : Text
                            | HumanActor
                            | Integer
                            | NonNegativeInteger
                            | Rfc3339Utc
                            | Uri
                            | UriWithScheme : Text
                            >
                      , path :
                          Optional
                            { allowSelf : Bool, externalUriSchemes : List Text }
                      , when : Optional { field : Text, hasValue : List Text }
                      }
                }
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , reference =
              None
                { allowSelf : Bool
                , externalUriSchemes : List Text
                , localPrefix : Text
                }
          , when = None { field : Text, hasValue : List Text }
          }
    }
  , NestedFieldRule =
    { actor =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Actor
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , boolean =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Boolean
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , bundlePath =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = Some
            { allowSelf = False, externalUriSchemes = [] : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , conditional =
        \ ( _
          : { allowedValues : List Text
            , cardinality : < Any | List | Scalar >
            , description : Optional Text
            , field : Text
            , format :
                Optional
                  < Actor
                  | Boolean
                  | Date
                  | DocumentHandle : Text
                  | HumanActor
                  | Integer
                  | NonNegativeInteger
                  | Rfc3339Utc
                  | Uri
                  | UriWithScheme : Text
                  >
            , path :
                Optional { allowSelf : Bool, externalUriSchemes : List Text }
            , when : Optional { field : Text, hasValue : List Text }
            }
          ) ->
        \(_ : { field : Text, hasValue : List Text }) ->
          _@1
          with when = Some _
    , date =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Date
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , documentHandle =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _@1
          , format = Some
              ( < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >.DocumentHandle
                  _
              )
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , documented =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = Some _
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , enum =
        \(_ : Text) ->
        \(_ : List Text) ->
          { allowedValues = _
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , humanActor =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.HumanActor
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , integer =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Integer
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , list =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.List
          , description = None Text
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , localOrExternalPath =
        \(_ : Text) ->
        \(_ : List Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _@1
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = Some { allowSelf = False, externalUriSchemes = _ }
          , when = None { field : Text, hasValue : List Text }
          }
    , nonNegativeInteger =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.NonNegativeInteger
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , plain =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , rfc3339Utc =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Rfc3339Utc
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , scalar =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Scalar
          , description = None Text
          , field = _
          , format =
              None
                < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , uri =
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _
          , format = Some
              < Actor
              | Boolean
              | Date
              | DocumentHandle : Text
              | HumanActor
              | Integer
              | NonNegativeInteger
              | Rfc3339Utc
              | Uri
              | UriWithScheme : Text
              >.Uri
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    , uriWithScheme =
        \(_ : Text) ->
        \(_ : Text) ->
          { allowedValues = [] : List Text
          , cardinality = < Any | List | Scalar >.Any
          , description = None Text
          , field = _@1
          , format = Some
              ( < Actor
                | Boolean
                | Date
                | DocumentHandle : Text
                | HumanActor
                | Integer
                | NonNegativeInteger
                | Rfc3339Utc
                | Uri
                | UriWithScheme : Text
                >.UriWithScheme
                  _
              )
          , path = None { allowSelf : Bool, externalUriSchemes : List Text }
          , when = None { field : Text, hasValue : List Text }
          }
    }
  }
}
