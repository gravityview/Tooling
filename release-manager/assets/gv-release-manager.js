/**
 * GravityView Release Manager
 *
 * @since     1.0.0
 *
 * @package   GravityView_Release_Manager
 *
 * @license   GPL2+
 * @author    Katz Web Services, Inc.
 * @link      http://gravityview.co
 * @copyright Copyright 2020, Katz Web Services, Inc.
 *
 * @global jQuery
 */

( function( $ ) {

	var release_list = {
		init: function() {

			var timer;
			var delay = 500;

			$( '.tablenav-pages a, .manage-column.sortable a, .manage-column.sorted a' ).on( 'click', function( e ) {

				e.preventDefault();

				var query = this.search.substring( 1 );

				var data = {
					paged: release_list.__query( query, 'paged' ) || '1',
					order: release_list.__query( query, 'order' ) || window.GV_RELEASE_MANAGER.default_order,
					orderby: release_list.__query( query, 'orderby' ) || window.GV_RELEASE_MANAGER.default_order_by,
				};

				release_list.update( data );
			} );

			$( 'input[name=paged]' ).on( 'keyup', function( e ) {

				if ( 13 == e.which ) {
					e.preventDefault();
				}

				var data = {
					paged: parseInt( $( 'input[name=paged]' ).val() ) || '1',
					order: $( 'input[name=order]' ).val() || window.GV_RELEASE_MANAGER.default_order,
					orderby: $( 'input[name=orderby]' ).val() || window.GV_RELEASE_MANAGER.default_order_by,
				};

				window.clearTimeout( timer );
				timer = window.setTimeout( function() {
					release_list.update( data );
				}, delay );
			} );

			$( '#gv-releases' ).on( 'submit', function( e ) {

				e.preventDefault();
			} );
		},

		update: function( data ) {

			$.ajax( {
				url: ajaxurl,
				data: $.extend(
					{
						_wpnonce: $( '#_wpnonce' ).val(),
						action: 'gv_release_manager_ajax_handle_request',
					},
					data,
				),
				success: function( response ) {

					if ( response.rows.length ) {
						$( '#the-list' ).html( response.rows );
					}
					if ( response.column_headers.length ) {
						$( 'thead tr, tfoot tr' ).html( response.column_headers );
					}
					if ( response.pagination.bottom.length ) {
						$( '.tablenav.top .tablenav-pages' ).html( $( response.pagination.top ).html() );
					}
					if ( response.pagination.top.length ) {
						$( '.tablenav.bottom .tablenav-pages' ).html( $( response.pagination.bottom ).html() );
					}

					release_list.init();
				},
			} );
		},

		/**
		 * Get variables from URL query string
		 *
		 * @see http://css-tricks.com/snippets/javascript/get-url-variables/
		 *
		 * @param    string    query The URL query part containing the variables
		 * @param    string    variable Name of the variable we want to get
		 *
		 * @return   string|boolean The variable value if available, false else.
		 */
		__query: function( query, variable ) {

			var vars = query.split( '&' );

			for ( var i = 0; i < vars.length; i++ ) {
				var pair = vars[ i ].split( '=' );

				if ( pair[ 0 ] == variable ) {
					return pair[ 1 ];
				}
			}

			return false;
		},
	};

	$( '#storage_path, #auth_token' ).after( ' (<a href="#" class="generate_random_value">random</a>)' );
	$( '.generate_random_value' ).on( 'click', function() {
		var randomValue = Array( 25 ).fill( 0 ).map( x => Math.random().toString( 36 ).charAt( 2 ) ).join( '' );

		$( this ).prevAll( 'input' ).val( randomValue );
	} );

	release_list.init();
} )( jQuery );
