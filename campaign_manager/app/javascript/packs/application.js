/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

// Rails UJS/ActiveStorage are optional for this UI; enable if needed
// require('@rails/ujs').start()
// require('@rails/activestorage').start()

import '../styles/application.css'
import '../styles/cube.css'

import ReactRailsUJS from 'react_ujs'
import React from 'react'
import ReactDOM from 'react-dom'

// Import components directly for global fallback
import CampaignDashboard from '../components/CampaignDashboard'
import PlaceholderRoot from '../components/PlaceholderRoot'

// Expose React for react-rails UJS
window.React = React
window.ReactDOM = ReactDOM

// Expose components globally as fallback (react_ujs will find them via require.context first, then fall back to window)
window.CampaignDashboard = CampaignDashboard
window.PlaceholderRoot = PlaceholderRoot

// Auto-register React components from app/javascript/components
// This uses require.context to find components, with fallback to window globals
const componentRequireContext = require.context('../components', true, /\.(js|jsx|ts|tsx)$/)
ReactRailsUJS.useContext(componentRequireContext)
