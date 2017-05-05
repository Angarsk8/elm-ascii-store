const moment = require('moment')
const Elm = require('./App.elm')

require('./main.css')

const INITIAL_FORMAT_DATE = 'ddd MMM DD YYYY HH:mm:ss ZZ'
const DESIRED_FORMAT_DATE = 'MMM DD, YYYY'

function formatDate(string) {
  const date = moment(string, INITIAL_FORMAT_DATE)
  const weekAgo = moment().subtract(7, 'days').startOf('day')

  if (date.isValid()) {
    return date.isBefore(weekAgo)
      ? `on ${date.format(DESIRED_FORMAT_DATE)}`
      : date.fromNow()
  }

  return string
}

function formatPrice(price) {
  return parseInt(price, 0) / 100
}

function formatProduct(products) {
  return Object.assign({}, products, {
    date: formatDate(products.date),
    price: formatPrice(products.price)
  })
}

function formatProducts(products) {
  return products.map(product => formatProduct(product))
}

const root = document.getElementById('root')
const app = Elm.App.embed(root, {
  nodeEnv: 'development',
  host: window.location.host
})

app.ports.formatProducts.subscribe(json => {
  const products = JSON.parse(json)
  const formattedProduct = formatProducts(products)
  app.ports.formattedProducts.send(JSON.stringify(formattedProduct))
})