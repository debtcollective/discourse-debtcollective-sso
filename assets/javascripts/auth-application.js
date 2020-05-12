/**
 * Discourse base
 */
//= require_tree ../../../../app/assets/javascripts/discourse-common/addon
//= require i18n-patches
//= require_tree ../../../../app/assets/javascripts/select-kit
//= require polyfills

/**
 * Discourse components
 */
//= require discourse/app/lib/text-direction.js
//= require discourse/app/components/text-field.js

/**
 * Auth app
 */
//= require ./auth/router
//= require ./auth/auth
//= require_tree ./auth/templates
//= require_tree ./auth/routes
//= require_tree ./auth/controllers
//= require_tree ./auth/initializers
