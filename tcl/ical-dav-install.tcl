namespace eval calendar {}

ad_proc -private calendar::register_implementation {
} {
    add ical virtual files via service contracts
} {
  
    set spec {
        name "ical"
        aliases {
	  get 		calendar::ical::GET
	  head		calendar::ical::HEAD
	  put		calendar::ical::PUT
	  propfind	calendar::ical::PROPFIND
	  delete 	calendar::ical::DELETE
	  mkcol 	calendar::ical::MKCOL
	  proppatch 	calendar::ical::PROPPATCH
	  copy 		calendar::ical::COPY
	  move 		calendar::ical::MOVE
	  lock 		calendar::ical::LOCK
	  unlock 	calendar::ical::UNLOCK
        }
	contract_name {dav}
	owner calendar
    }
    
    acs_sc::impl::new_from_spec -spec $spec
}

ad_proc -private calendar::unregister_implementation {
} {
    remove service contract implementation fo ical
} {
    acs_sc::impl::delete -contract_name dav -impl_name ical
}