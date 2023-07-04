import 'focus-visible'

document.documentElement.classList.remove('no-js')

const API = 'https://nbh86frdn8.execute-api.eu-central-1.amazonaws.com'

//Get Views
async function getViews() {
    try {
        let response = await fetch(API)
        let data = await response.json()
        return data
    } catch (error) {
        console.log(error)
    }
}

// Render Views
async function renderViews() {
    const views = await getViews()
    if (views) {
        const viewsContainer = document.querySelector('#views')
        viewsContainer.innerHTML = views
    }
}

renderViews()

// Scroll State
const onScroll = () => {
    const scrollClassName = 'js-scrolled'
    const scrollTreshold = 200
    const isOverTreshold = window.scrollY > scrollTreshold

    if (isOverTreshold) {
        document.documentElement.classList.add(scrollClassName)
    } else {
        document.documentElement.classList.remove(scrollClassName)
    }
}
window.addEventListener('scroll', onScroll, { passive: true })

// Print Button
const printButton = document.querySelector('.js-print')
printButton.addEventListener('click', () => {
    window.print()
})
